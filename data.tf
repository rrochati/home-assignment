# Get your current AWS identity
data "aws_availability_zones" "available" {
  filter {
	name   = "opt-in-status"
	values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "example" {
  description             = "KMS key with proper permissions"
  deletion_window_in_days = 10

  policy = jsonencode({
	Version = "2012-10-17"
	Statement = [
	  {
	    Sid    = "Enable IAM User Permissions"
	    Effect = "Allow"
	    Principal = {
	      AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
	    }
	    Action   = "kms:*"
	    Resource = "*"
	  },
	  {
	    Sid    = "Allow access for Key Administrators"
	    Effect = "Allow"
	    Principal = {
	      AWS = [
	        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
	        # Add other admin users/roles as needed
	      ]
	    }
	    Action = [
	      "kms:Create*",
	      "kms:Describe*",
	      "kms:Enable*",
	      "kms:List*",
	      "kms:Put*",
	      "kms:Update*",
	      "kms:Revoke*",
	      "kms:Disable*",
	      "kms:Get*",
	      "kms:Delete*",
	      "kms:TagResource",
	      "kms:UntagResource",
	      "kms:ScheduleKeyDeletion",
	      "kms:CancelKeyDeletion"
	    ]
	    Resource = "*"
	  }
	]
  })

  tags = {
	Name = "example-kms-key"
  }
}

resource "aws_kms_alias" "example" {
  name          = "alias/example-key-${random_id.suffix.hex}"
  target_key_id = aws_kms_key.example.key_id
}

# Add a random suffix generator
resource "random_id" "suffix" {
  byte_length = 4
}