module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"  # This version works with AWS provider ~> 5.0

  cluster_name    = var.cluster_name
  cluster_version = "1.34"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  cloudwatch_log_group_retention_in_days = 3

  create_cluster_primary_security_group_tags = true

  tags = {
  #  Project     = var.project_name
	Environment = var.environment
	ManagedBy   = "Terraform"
  }

  cluster_tags = {
	Type      = "EKS-Cluster"
	ManagedBy = "DevOps"
  }

  # EKS Managed Node Group configuration for smaller instances
  eks_managed_node_group_defaults = {
	instance_types = var.node_group_instance_types
	attach_cluster_primary_security_group = true
	enable_monitoring = true
	
	# Optimized for smaller instances
	ami_type  = "AL2023_x86_64_STANDARD"
	disk_size = 20  # Smaller disk for cost optimization
	disk_type = "gp3"
  }

  eks_managed_node_groups = {
	main = {
	  name = "${var.cluster_name}-node-group"

	  # Use smaller instance types with fallbacks
	  instance_types = var.node_group_instance_types
	  capacity_type  = "ON_DEMAND"
	  
	  min_size     = var.node_group_min_size
	  max_size     = var.node_group_max_size
	  desired_size = var.node_group_desired_size

	  labels = {
	    Environment = var.environment
	  #  Project     = var.project_name
	    NodeGroup   = "main"
	  }

	  tags = {
	    Name        = "${var.cluster_name}-node-group"
	  #  Project     = var.project_name
	    Environment = var.environment
	    ManagedBy   = "Terraform"
	  }
	}
  }
}
