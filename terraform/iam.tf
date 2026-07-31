data "aws_iam_policy_document" "jenkins_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.project}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume.json

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# Grants shell access via AWS Systems Manager Session Manager instead of an
# open SSH port and a .pem key (see ADR-0001).
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least-privilege access so Jenkins can run terraform init/plan/apply using
# the instance role instead of static AWS keys in a Jenkins credential.
data "aws_iam_policy_document" "jenkins_permissions" {
  statement {
    sid     = "StateBucketAccess"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}",
      "arn:aws:s3:::${var.tf_state_bucket}/*",
    ]
  }

  statement {
    sid       = "ReadDeploySecrets"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${var.aws_region}:*:parameter/dhl/jenkins/*"]
  }

  # Mirrors what dhl-tfuser needed to add iteratively (see
  # aws-console-setup-checklist.md) - the box's own role needs the same
  # permissions to run terraform apply against its own infrastructure via
  # the Jenkins pipeline, not just a human running it from WSL.
  statement {
    sid = "ManageOwnIamRole"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:TagRole", "iam:TagInstanceProfile",
      "iam:ListRoleTags", "iam:ListInstanceProfileTags",
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::*:role/${var.project}-*",
      "arn:aws:iam::*:instance-profile/${var.project}-*",
    ]
  }

  statement {
    sid = "ManageSchedule"
    actions = [
      "events:PutRule", "events:DeleteRule", "events:DescribeRule",
      "events:PutTargets", "events:RemoveTargets", "events:ListTargetsByRule",
      "events:TagResource", "events:ListTagsForResource",
    ]
    resources = ["arn:aws:events:${var.aws_region}:*:rule/${var.project}-*"]
  }

  statement {
    sid       = "ManageBudget"
    actions   = ["budgets:ViewBudget", "budgets:ModifyBudget", "budgets:ListTagsForResource"]
    resources = ["arn:aws:budgets::*:budget/*"]
  }

  # NOTE: scoped to actions rather than specific resource ARNs, because this
  # role manages the very EC2/SG/EBS/EIP resources it runs on (a self-
  # referential apply). Acceptable for a single-owner project; if this role
  # is ever used for anything beyond this Jenkins box, tighten with
  # tag-based conditions (aws:ResourceTag/Project = var.project).
  statement {
    sid = "ManageJenkinsInfra"
    actions = [
      "ec2:Describe*",
      "ec2:CreateTags",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:ModifyInstanceAttribute",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "jenkins_permissions" {
  name   = "${var.project}-jenkins-permissions"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.jenkins_permissions.json
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}
