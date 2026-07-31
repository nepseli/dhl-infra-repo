#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

# --- OS baseline -----------------------------------------------------------
# Deliberately not running a full `yum update -y` on every boot: it was the
# single biggest contributor to slow first-boot times. Base AMI patching is
# handled by rotating to the latest AMI from data-ami.tf periodically instead.
dnf install -y java-21-amazon-corretto git

# --- Jenkins package ---------------------------------------------------------
# curl, not wget: this AL2023 AMI ships curl-minimal by default but not wget.
curl -sSL -o /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
dnf install -y jenkins

# --- Terraform CLI, so pipeline stages running on this box can use it -------
dnf install -y yum-utils
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
dnf install -y terraform

# --- Stop /tmp being a tiny RAM-backed filesystem ---------------------------
# Amazon Linux mounts /tmp as tmpfs sized ~50% of RAM by default. On a small
# instance that fills fast and Jenkins reports "disk space below threshold".
# Masking tmp.mount makes /tmp a normal directory on the root EBS volume
# instead, so its size tracks disk (20GB), not RAM.
systemctl mask tmp.mount
# tmp.mount may already be active for this boot; masking only prevents it
# on future boots, so unmount it now if present to free /tmp immediately.
if mountpoint -q /tmp; then
  umount /tmp
fi

# --- Attach the dedicated JENKINS_HOME volume -------------------------------
# t3 instances are Nitro-based: the device name given in Terraform
# (/dev/xvdf) is exposed via a udev rule as a symlink to the real NVMe
# device (amazon-ec2-utils ships this mapping by default on Amazon Linux).
DATA_DEV=/dev/xvdf
for i in $(seq 1 30); do
  [ -e "$DATA_DEV" ] && break
  sleep 2
done

if ! blkid "$DATA_DEV" >/dev/null 2>&1; then
  mkfs -t xfs "$DATA_DEV"
fi

systemctl stop jenkins || true

mkdir -p /mnt/jenkins-data
mount "$DATA_DEV" /mnt/jenkins-data
if [ -d /var/lib/jenkins ] && [ "$(ls -A /var/lib/jenkins 2>/dev/null)" ]; then
  rsync -a /var/lib/jenkins/ /mnt/jenkins-data/
fi
umount /mnt/jenkins-data

DATA_UUID=$(blkid -s UUID -o value "$DATA_DEV")
if ! grep -q "$DATA_UUID" /etc/fstab; then
  echo "UUID=$${DATA_UUID}  /var/lib/jenkins  xfs  defaults,nofail  0  2" >> /etc/fstab
fi
mount /var/lib/jenkins
chown -R jenkins:jenkins /var/lib/jenkins

# --- Headless plugin install ------------------------------------------------
# Plugin list is baked in from plugins.txt at plan time (see main.tf) so it
# stays version-controlled instead of being edited by hand on the box.
mkdir -p /opt/dhl
cat > /opt/dhl/plugins.txt <<'PLUGINS_EOF'
${plugins_txt}
PLUGINS_EOF

JENKINS_WAR=/usr/share/java/jenkins.war
PLUGIN_CLI_JAR=/opt/dhl/jenkins-plugin-manager.jar
DOWNLOAD_URL=$(curl -sSL https://api.github.com/repos/jenkinsci/plugin-installation-manager-tool/releases/latest \
  | grep -o 'https://[^"]*\.jar' | head -n1) || true

if [ -n "$${DOWNLOAD_URL:-}" ]; then
  curl -sSL -o "$PLUGIN_CLI_JAR" "$DOWNLOAD_URL" || true
fi

if [ -f "$PLUGIN_CLI_JAR" ]; then
  java -jar "$PLUGIN_CLI_JAR" \
    --war "$JENKINS_WAR" \
    --plugin-download-directory /var/lib/jenkins/plugins \
    --plugin-file /opt/dhl/plugins.txt \
    --latest false \
    || echo "plugin auto-install failed, continuing - install manually via the Jenkins UI"
  chown -R jenkins:jenkins /var/lib/jenkins/plugins || true
else
  echo "could not fetch plugin-installation-manager-tool jar, skipping auto-install - install plugins manually via the Jenkins UI"
fi

# --- Start Jenkins -----------------------------------------------------------
# Setup wizard, admin account, and AWS/GitHub credential entry are still
# manual (partial-automation choice from ADR-0001) - grab the initial admin
# password from /var/lib/jenkins/secrets/initialAdminPassword after this.
systemctl enable jenkins
systemctl start jenkins
