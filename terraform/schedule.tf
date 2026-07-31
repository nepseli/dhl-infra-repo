# Automatic stop/start schedule so a personal/dev Jenkins box isn't billed
# 24/7. Uses EventBridge rules that trigger the built-in SSM Automation
# runbooks AWS-StopEC2Instance / AWS-StartEC2Instance - no Lambda needed.
#
# NOTE: if AWS-StopEC2Instance/AWS-StartEC2Instance execution fails with a
# permissions error in SSM Automation's execution history, it means this
# account requires an explicit AutomationAssumeRole parameter rather than
# inheriting the EventBridge target role's permissions - add an
# ssm.amazonaws.com-trusted role with the same ec2:Stop/StartInstances
# permissions and pass its ARN as an "AutomationAssumeRole" key in the
# input blocks below.

data "aws_iam_policy_document" "eventbridge_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge_ssm" {
  count              = var.enable_schedule ? 1 : 0
  name               = "${var.project}-jenkins-schedule-role"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume.json

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "eventbridge_ssm_permissions" {
  statement {
    sid     = "RunAutomation"
    actions = ["ssm:StartAutomationExecution"]
    resources = [
      "arn:aws:ssm:${var.aws_region}::automation-definition/AWS-StopEC2Instance:*",
      "arn:aws:ssm:${var.aws_region}::automation-definition/AWS-StartEC2Instance:*",
    ]
  }

  statement {
    sid       = "StopStartInstance"
    actions   = ["ec2:StopInstances", "ec2:StartInstances", "ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "eventbridge_ssm_permissions" {
  count  = var.enable_schedule ? 1 : 0
  name   = "${var.project}-jenkins-schedule-permissions"
  role   = aws_iam_role.eventbridge_ssm[0].id
  policy = data.aws_iam_policy_document.eventbridge_ssm_permissions.json
}

resource "aws_cloudwatch_event_rule" "stop_schedule" {
  count               = var.enable_schedule ? 1 : 0
  name                = "${var.project}-jenkins-stop"
  description         = "Stop the Jenkins instance on a schedule to control cost"
  schedule_expression = var.schedule_stop_cron
}

resource "aws_cloudwatch_event_rule" "start_schedule" {
  count               = var.enable_schedule ? 1 : 0
  name                = "${var.project}-jenkins-start"
  description         = "Start the Jenkins instance on a schedule"
  schedule_expression = var.schedule_start_cron
}

resource "aws_cloudwatch_event_target" "stop_target" {
  count    = var.enable_schedule ? 1 : 0
  rule     = aws_cloudwatch_event_rule.stop_schedule[0].name
  arn      = "arn:aws:ssm:${var.aws_region}::automation-definition/AWS-StopEC2Instance:$DEFAULT"
  role_arn = aws_iam_role.eventbridge_ssm[0].arn

  input = jsonencode({
    InstanceId = [aws_instance.jenkins.id]
  })
}

resource "aws_cloudwatch_event_target" "start_target" {
  count    = var.enable_schedule ? 1 : 0
  rule     = aws_cloudwatch_event_rule.start_schedule[0].name
  arn      = "arn:aws:ssm:${var.aws_region}::automation-definition/AWS-StartEC2Instance:$DEFAULT"
  role_arn = aws_iam_role.eventbridge_ssm[0].arn

  input = jsonencode({
    InstanceId = [aws_instance.jenkins.id]
  })
}
