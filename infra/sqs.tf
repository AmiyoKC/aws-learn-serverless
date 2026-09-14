resource "aws_sqs_queue" "file_processing_queue" {
    name = "file-processing-queue"
    visibility_timeout_seconds = 60
    redrive_policy = jsonencode({
        deadLetterTargetArn = aws_sqs_queue.file_processing_dlq.arn
        maxReceiveCount = 3
    })
}

resource "aws_sqs_queue" "file_processing_dlq" {
    name = "file-processing-dlq"
}

resource "aws_sqs_queue_policy" "sqs_queue_policy" {
  queue_url = aws_sqs_queue.file_processing_queue.url
  policy    = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.file_processing_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.s3_object_created.arn
          }
        }
      }
    ]
  })
}