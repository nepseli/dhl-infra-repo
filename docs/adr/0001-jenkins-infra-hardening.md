# ADR-0001: Jenkins EC2 infra hardening and automation

**Status:** Accepted
**Date:** 2026-07-30
**Deciders:** Prashanth (project owner)

## Context

The Jenkins controller for the `dhl` project runs on a single EC2 instance provisioned by Terraform in `terraform/`. As built, it has five interlocking problems: the box is undersized (t3.micro, 1GB RAM), which caps `/tmp` (tmpfs, ~50% of RAM) and causes the built-in node to go offline on disk-space alarms; the security group opens SSH and the Jenkins UI to `0.0.0.0/0`; Terraform state is local-only despite the Jenkinsfile assuming a remote S3/DynamoDB backend, so concurrent runs from a laptop and from Jenkins itself can silently diverge; AWS credentials are wired into the Jenkinsfile in a way that doesn't match what the AWS provider actually reads; and the entire Jenkins bootstrap (admin login, plugin installs, credential entry) is manual and has to be redone on every rebuild.

Constraints: this is a personal/dev project (not a team environment), cost should stay in the tens-of-dollars-per-month range, and the owner wants to keep doing hands-on Terraform/Jenkins work rather than replacing this with a managed CI service.

## Decision

Harden and automate the existing single-instance design rather than move to a managed Jenkins service or a multi-node/HA setup — the traffic and team-size don't justify that complexity or cost. Specifically:

- Move to `t3.medium` with a dedicated EBS volume for `JENKINS_HOME`, decoupling Jenkins storage from instance RAM.
- Add a real S3 + DynamoDB remote backend, provisioned via a small one-time bootstrap Terraform config.
- Replace static AWS keys in Jenkins with an IAM instance role.
- Replace open SSH with AWS Systems Manager Session Manager.
- Automate plugin installation via `user-data.sh`; keep the admin login and credential entry manual for now (partial automation — full JCasC automation is an explicit candidate for a follow-up ADR if this proves insufficient).
- Add an Elastic IP, and scheduled stop/start plus a budget alert for cost control.
- Defer HTTPS (ALB + ACM) — not worth the added cost/complexity for a personal project yet.

## Options considered

### Option A: Harden the existing single-instance design (chosen)

| Dimension | Assessment |
|---|---|
| Complexity | Low-medium — incremental changes to existing Terraform |
| Cost | ~$25-30/mo total (t3.medium + EBS + EIP + backend, ALB deferred) |
| Scalability | Not needed at this scale (one owner, one project) |
| Team familiarity | High — owner already knows this stack |

**Pros:** minimal disruption, keeps the learning value of running real infra, addresses every concrete problem observed.
**Cons:** still a single point of failure; still Jenkins-on-EC2 rather than a managed service, so OS/Jenkins patching stays a manual concern long-term.

### Option B: Managed CI (e.g. GitHub Actions, CircleCI) instead of self-hosted Jenkins

| Dimension | Assessment |
|---|---|
| Complexity | Low ongoing, but throws away the existing Jenkinsfile investment |
| Cost | Free tier likely sufficient for personal use |
| Scalability | High, but irrelevant here |
| Team familiarity | Would require learning a new pipeline syntax |

**Pros:** no infrastructure to babysit, no more disk/RAM/patching concerns.
**Cons:** discards the explicit goal of running Jenkins on self-managed AWS infra; doesn't serve the learning objective of this project.

### Option C: Multi-node Jenkins (controller + separate build agent) using the existing orphaned `playbook.yaml`

| Dimension | Assessment |
|---|---|
| Complexity | Medium-high — a second EC2 instance, agent connection setup, Ansible wiring |
| Cost | Roughly double the compute cost |
| Scalability | Better build isolation, but no current workload needs it |
| Team familiarity | Medium — Ansible playbook already exists but is untested/unwired |

**Pros:** keeps builds off the controller, matches Jenkins best practice.
**Cons:** doubles cost and complexity for a workload (single-project Terraform applies) that doesn't need it yet. Revisit if build volume grows.

## Trade-off analysis

The biggest trade-off is Option A's acceptance of continued manual OS/Jenkins maintenance in exchange for low cost and complexity. Partial (not full) bootstrap automation was chosen deliberately: full JCasC automation removes more manual toil but adds a meaningfully larger surface (rendering config, wiring SSM-backed credential providers, testing unattended first-boot) for a single-operator project where the manual login only happens on full rebuilds, which should now be rare once state is stable and shared.

## Consequences

- Easier: state is safe and shared across your laptop and Jenkins; the disk-space alarm is structurally gone (not just delayed); the Jenkins URL is stable; no static AWS keys to rotate or leak.
- Harder: a couple of new one-time AWS console steps are required before the first apply (S3 bucket, DynamoDB table, IAM permission check — see the AWS console checklist); the region is now fixed rather than selectable per Jenkins build.
- To revisit later: full JCasC automation if manual credential re-entry becomes a recurring annoyance; HTTPS via ALB+ACM if this ever needs to be reachable by anyone other than the owner; a second build-agent node (Option C) if build volume or isolation needs grow.

## Action items

1. [ ] Bootstrap Terraform config for S3 state bucket + DynamoDB lock table
2. [ ] Variable-ize `provider.tf`/`variables.tf`/`main.tf`, wire the AMI data source
3. [ ] IAM instance role replacing static AWS keys
4. [ ] `t3.medium` + dedicated EBS volume for `JENKINS_HOME`
5. [ ] Security group: drop SSH, variable-ize the 8080 rule
6. [ ] Elastic IP
7. [ ] `user-data.sh`: mask tmpfs, mount data volume, headless plugin install
8. [ ] Scheduled stop/start + budget alert
9. [ ] Jenkinsfile alignment + repo hygiene (`.gitignore`, `tfvars.example`)
10. [ ] Validate (`terraform fmt`/`validate`), self code-review, update the living plan doc
