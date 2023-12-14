data "archive_file" "lambda" {
  type        = "zip"
  excludes = [ "others", "__pycache__"]
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/../tmp/tmp_gen_code.zip"
}

resource "aws_lambda_layer_version" "pg8000_layer" {
  filename   = "${path.module}/../tmp/tmp_gen_layer.zip"
  layer_name = "pg8000_layer"

  compatible_runtimes = ["python3.11"]
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

data "aws_iam_policy_document" "sm_document" {
  statement {

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "cw_policy" {
  name_prefix = "cw-policy-"
  policy      = data.aws_iam_policy_document.cw_document.json
}

resource "aws_iam_policy" "ec2_policy" {
  name_prefix = "ec2-policy-"
  policy      = data.aws_iam_policy_document.ec2_document.json
}

resource "aws_iam_policy" "sm_policy" {
  name_prefix = "sm-policy-"
  policy      = data.aws_iam_policy_document.sm_document.json
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

resource "aws_iam_role_policy_attachment" "lambda_sm_policy_attachment" {
  role       = aws_iam_role.generator_role.name
  policy_arn = aws_iam_policy.sm_policy.arn
}

resource "aws_lambda_function" "init_db" {
  description   = "Lambda to initialise the database"
  filename      = data.archive_file.lambda.output_path
  function_name = "init_db"
  role          = aws_iam_role.generator_role.arn
  handler       = "generator.initialisation.init_db"
  runtime       = "python3.11"
  timeout       = 5

  layers = [aws_lambda_layer_version.pg8000_layer.arn]

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
      DB_HOST : aws_db_instance.mock_oltp.address,
      DB_NAME : aws_db_instance.mock_oltp.db_name,
      DB_PORT : aws_db_instance.mock_oltp.port,
      DB_USER : var.rds_oltp_usr,
      DB_PASS : var.rds_oltp_pass
    }
  }
}

resource "aws_cloudwatch_log_group" "db_init_log_group" {
  name = "/aws/lambda/${aws_lambda_function.init_db.function_name}"
  depends_on = [aws_lambda_function.init_db]
}

data "aws_lambda_invocation" "init_db" {
  function_name = aws_lambda_function.init_db.function_name

  input = jsonencode(
    {
      "test_input" : aws_db_instance.mock_oltp.db_name
    }
  )
}

output "db_init_result" {
  value = jsondecode(data.aws_lambda_invocation.init_db.result)
}
