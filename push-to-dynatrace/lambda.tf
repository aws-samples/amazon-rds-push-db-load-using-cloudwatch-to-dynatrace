/* 
  Lambda function to pull PI metrics and push to CloudWatch 
*/

/* 
  Archive the python script
*/
data "archive_file" "python_lambda_package" {
  type = "zip"
  source_file = "${path.module}/code/lambda_function.py"
  output_path = "lfx.zip"
}

/*
  Create the lamda function
*/
resource "aws_lambda_function" "pi_lambda_function" {
    function_name = "lambdaPI"    
    filename      = "lfx.zip"
    source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
    role          = aws_iam_role.pi_lambda_role.arn
    runtime       = "python3.9"
    handler       = "lambda_function.lambda_handler"
    timeout       = 15
    environment {
      variables = {
        PINamespace = "${var.PINamespace}"
        RDSFilterInTags = join(";", formatlist("%s=%s", keys(var.RDSFilterInTags), values(var.RDSFilterInTags)))
      }
    }
   tracing_config {
     mode = "Active"
   }
}

/*
  Create user role for lambda function
*/
data "aws_iam_policy_document" "lambda_trust_policy" {
  statement {
    actions    = ["sts:AssumeRole"]
    effect     = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_policy_doc" {
  statement{
    actions= [
      "logs:CreateLogGroup"
    ]
    effect= "Allow"
    resources = ["arn:aws:logs:${var.AWSRegion}:${var.AWSAccountID}:*"]
  }
  statement{
    actions= [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    effect= "Allow"
    resources = ["arn:aws:logs:${var.AWSRegion}:${var.AWSAccountID}:log-group:/aws/lambda/lambdaPI:*"]
  }
  statement{
    actions= [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:PutMetricData",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "rds:Describe*",
      "rds:ListTagsForResource",
      "rds:DescribeDBInstances"
    ]
    effect= "Allow"    
    resources = ["*"]
  }
  statement {
    actions= [
      "pi:GetDimensionKeyDetails",
      "pi:GetResourceMetadata",
      "pi:ListAvailableResourceDimensions",
      "pi:DescribeDimensionKeys",
      "pi:ListAvailableResourceMetrics",
      "pi:GetResourceMetrics"
    ]
    effect= "Allow"
    #we want to get info about all RDS databases in this account and so we are using a * under rds metrics
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["arn:aws:pi:${var.AWSRegion}:${var.AWSAccountID}:metrics/rds/*"]
  }	  
}

resource "aws_iam_role" "pi_lambda_role" {
  name = "lambda-pi-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust_policy.json
   # Attach the policy
  inline_policy {
	name = "policy-lambda-permissions"
    policy = data.aws_iam_policy_document.lambda_policy_doc.json
  }
}

/* 
  Create a lambda trigger that will run every X minutes 
*/

resource "aws_cloudwatch_event_rule" "every_minute" {
    name = "every-minute"
    description = "Fires every minute"
    schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "call_pi_lambda_every_minute" {
    rule = "${aws_cloudwatch_event_rule.every_minute.name}"
    target_id = "pi_lambda_function"
    arn = "${aws_lambda_function.pi_lambda_function.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_pi_lambda_function" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.pi_lambda_function.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.every_minute.arn}"
}
