aws_region   = "us-east-1"
cluster_name = "ha-eks"
environment  = "sandbox"
project_name = "home_assignment"
namespace    = "webapp"

# Node group configuration - Use multiple instance types for better availability
node_group_instance_types = ["t3.small", "t3.medium", "t3.large", "m5.large"]
node_group_desired_size   = 2
node_group_min_size       = 1
node_group_max_size       = 4

# SQS queue name
sqs_queue_name = "assignment-keda-queue"