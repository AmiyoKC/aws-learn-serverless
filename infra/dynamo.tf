resource "aws_dynamodb_table" "file_processing_log" {
  name         = "file-processing-log-tf"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "file_key"
  range_key    = "line_id"

  attribute {
    name = "file_key"
    type = "S"
  }

  attribute {
    name = "line_id"
    type = "S"
  }
}