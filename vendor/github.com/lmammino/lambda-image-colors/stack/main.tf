provider "aws" {
  region = "us-east-1"
}

resource "random_id" "stack_id" {
  byte_length = 16
}

variable "stack_name" {
  default = "image-colors"
}

variable "bucket_name-prefix" {
  default = "image-colors-"
}

resource "aws_s3_bucket" "images_bucket" {
  bucket = "${var.bucket_name-prefix}${random_id.stack_id.hex}"
  acl    = "private"

  tags = {
    Name     = "${var.bucket_name-prefix}${random_id.stack_id.hex}"
    Stack    = "${var.stack_name}"
    Stack_id = "${random_id.stack_id.hex}"
  }
}

resource "aws_iam_role" "image-colors-lambda" {
  name = "image-colors-lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "image-colors-lambda-s3-access" {
  name = "image-colors-lambda-s3-access"
  role = "${aws_iam_role.image-colors-lambda.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.images_bucket.arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObjectTagging"
      ],
      "Resource": [
        "${aws_s3_bucket.images_bucket.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "image-colors-lambda-cloudwatch-log-group" {
  name              = "/aws/lambda/image-colors"
  retention_in_days = 7

  tags = {
    Stack    = "${var.stack_name}"
    Stack_id = "${random_id.stack_id.hex}"
  }
}

resource "aws_iam_role_policy" "image-colors-lambda-cloudwatch-access" {
  name = "image-colors-lambda-cloudwatch-access"
  role = "${aws_iam_role.image-colors-lambda.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream"
      ],
      "Resource": [
        "${aws_cloudwatch_log_group.image-colors-lambda-cloudwatch-log-group.arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents"
      ],
      "Resource": [
        "${aws_cloudwatch_log_group.image-colors-lambda-cloudwatch-log-group.arn}:*"
      ]
    }
  ]
}
EOF
}

resource "aws_lambda_function" "image-colors" {
  filename      = "../build/image-colors.zip"
  function_name = "image-colors"
  role          = "${aws_iam_role.image-colors-lambda.arn}"
  handler       = "image-colors"

  source_code_hash = "${filebase64sha256("../build/image-colors.zip")}"

  runtime = "go1.x"

  memory_size                    = 256
  timeout                        = 30
  reserved_concurrent_executions = 10
  publish                        = true

  tags = {
    Name     = "image-colors"
    Stack    = "${var.stack_name}"
    Stack_id = "${random_id.stack_id.hex}"
  }
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "image-colors-AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.image-colors.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.images_bucket.arn}"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${aws_s3_bucket.images_bucket.id}"

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.image-colors.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }
}

output "stack_id" {
  value = "${random_id.stack_id.hex}"
}

output "s3_bucket" {
  value = "${aws_s3_bucket.images_bucket.id}"
}

output "cloudwatch_log_group" {
  value = "${aws_cloudwatch_log_group.image-colors-lambda-cloudwatch-log-group.arn}"
}
