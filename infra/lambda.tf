data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda_src/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "process_s3_file" {
  function_name = "tf-process-s3-file"
  runtime       = "python3.13"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_exec_role.arn

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}


