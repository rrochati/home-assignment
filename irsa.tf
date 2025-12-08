# IAM Role for Service Account (IRSA) for KEDA
module "keda_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${substr(var.cluster_name, 0, 15)}-keda"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["keda:keda-operator"]
    }
  }

  role_policy_arns = {
    keda_sqs_policy = aws_iam_policy.keda_sqs_policy.arn
  }

  tags = local.common_tags
}

# IAM Policy for KEDA to access SQS
resource "aws_iam_policy" "keda_sqs_policy" {
  name        = "${var.cluster_name}-keda-sqs-policy"
  description = "IAM policy for KEDA to access SQS queues"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ListQueues"
        ]
        Resource = [
          aws_sqs_queue.keda_queue.arn,
          "${aws_sqs_queue.keda_queue.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ListQueues"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}