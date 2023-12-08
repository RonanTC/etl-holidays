data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../src/generator"
  output_path = "${path.module}/../tmp_generator.zip"
}

data "aws_iam_policy_document" "assume_role_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cw_document" {
  statement {

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "ec2_document" {
  statement {

    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "cw_policy" {
  name_prefix = "sm-policy-"
  policy      = data.aws_iam_policy_document.cw_document.json
}

resource "aws_iam_policy" "ec2_policy" {
  name_prefix = "ec2-policy-"
  policy      = data.aws_iam_policy_document.ec2_document.json
}

resource "aws_iam_role" "generator_role" {
  name_prefix        = "role-generator-"
  assume_role_policy = data.aws_iam_policy_document.assume_role_document.json
}

resource "aws_iam_role_policy_attachment" "lambda_cw_policy_attachment" {
  role       = aws_iam_role.generator_role.name
  policy_arn = aws_iam_policy.cw_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_ec2_policy_attachment" {
  role       = aws_iam_role.generator_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

resource "aws_lambda_function" "init_db" {
  description   = "Lambda to initialise the database"
  filename      = data.archive_file.lambda.output_path
  function_name = "init_db"
  role          = aws_iam_role.generator_role.arn
  handler       = "data_generator.init_db"
  runtime       = "python3.11"
  timeout       = 180

  vpc_config {
    subnet_ids = [
      aws_subnet.etl_hols_subnet_a.id,
      aws_subnet.etl_hols_subnet_b.id,
      aws_subnet.etl_hols_subnet_c.id
    ]
    security_group_ids = [aws_security_group.etl_hols_generator_sg.id]
  }
  environment {
    variables = {
      env_var = "123"
    }
  }
}

data "aws_lambda_invocation" "init_db" {
  function_name = aws_lambda_function.init_db.function_name

  input = jsonencode(
    {
      "test_key" : "test_value"
    }
  )
}

output "db_init_result" {
  value = jsondecode(data.aws_lambda_invocation.init_db.result)
}
