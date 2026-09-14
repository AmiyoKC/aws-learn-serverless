resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "s3-object-created-to-sqs"
  description = "Route S3 Object Created events to the file processing queue"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.file_upload_bucket.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "file_processing_queue" {
  rule = aws_cloudwatch_event_rule.s3_object_created.name
  arn  = aws_sqs_queue.file_processing_queue.arn

  depends_on = [aws_sqs_queue_policy.sqs_queue_policy]
}