# SQS Queue for KEDA autoscaling
resource "aws_sqs_queue" "keda_queue" {
  name                      = var.sqs_queue_name
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 0

  tags = local.common_tags
}

# SQS Queue Policy with specific user access
resource "aws_sqs_queue_policy" "keda_queue_policy" {
  queue_url = aws_sqs_queue.keda_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowKEDAAccess"
        Effect = "Allow"
        Principal = {
          AWS = module.keda_irsa.iam_role_arn
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.keda_queue.arn
      },
      {
        Sid    = "AllowCurrentUserAccess"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
        Action = [
          "sqs:*"
        ]
        Resource = aws_sqs_queue.keda_queue.arn
      }
    ]
  })
}

# Dead Letter Queue (optional but recommended)
resource "aws_sqs_queue" "keda_dlq" {
  name = "${var.sqs_queue_name}-dlq"

  tags = local.common_tags
}

# Redrive policy for the main queue
resource "aws_sqs_queue_redrive_policy" "keda_queue_redrive" {
  queue_url = aws_sqs_queue.keda_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.keda_dlq.arn
    maxReceiveCount     = 3
  })
}