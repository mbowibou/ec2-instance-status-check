provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_cloudwatch_event_rule" "ec2-status-check-event" {
  name                = "ec2-status-check-event"
  description         = "check missing EC2 statuss event"
  schedule_expression = "cron(0 02 * * ? *)"
}

resource "aws_cloudwatch_event_target" "check-file-event-lambda-target" {
  target_id = "check-file-event-lambda-target"
  rule      = "${aws_cloudwatch_event_rule.ec2-status-check-event.name}"
  arn       = "${aws_lambda_function.ec2_status_check_lambda.arn}"
  input = <<EOF
{
  "topic": "${var.devops_sns_topic_arn}"
}
EOF
}

resource "aws_iam_role" "ec2_status_check_lambda" {
    name = "ec2_status_check_lambda"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "status-check-ec2-access-ro" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
    ]
    resources = [
      "*",
    ]
  }
}

data "aws_iam_policy_document" "status-check-sns-publish" {
  statement {
    actions = [
      "SNS:Publish"
    ]
    resources = [
      "${var.devops_sns_topic_arn}"
    ]
  }
}

resource "aws_iam_policy" "status-check-ec2-access-ro" {
  name    = "status-check-ec2-access-ro"
  path    = "/"
  policy  = "${data.aws_iam_policy_document.status-check-ec2-access-ro.json}"
}

resource "aws_iam_policy" "status-check-sns-publish" {
  name    = "status-check-sns-publish"
  path    = "/"
  policy  = "${data.aws_iam_policy_document.status-check-sns-publish.json}"
}

resource "aws_iam_role_policy_attachment" "status-check-ec2-access-ro" {
  role       = "${aws_iam_role.ec2_status_check_lambda.name}"
  policy_arn = "${aws_iam_policy.status-check-ec2-access-ro.arn}"
}

resource "aws_iam_role_policy_attachment" "status-check-sns-publish" {
  role       = "${aws_iam_role.ec2_status_check_lambda.name}"
  policy_arn = "${aws_iam_policy.status-check-sns-publish.arn}"
}

resource "aws_iam_role_policy_attachment" "basic-exec-role" {
  role       = "${aws_iam_role.ec2_status_check_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_file" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ec2_status_check_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.ec2-status-check-event.arn}"
}

resource "aws_lambda_function" "ec2_status_check_lambda" {
  filename      = "status_check_lambda.zip"
  function_name = "status_check"
  description   = "checks instances for missing TEAM and ENVIRONMENT status"
  role          = "${aws_iam_role.ec2_status_check_lambda.arn}"
  handler       = "status_check.handler"
  runtime       = "python3.6"
  timeout       = 30
  source_code_hash = "${base64sha256(file("status_check_lambda.zip"))}"
}
