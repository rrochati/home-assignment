module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.32"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  create_cluster_primary_security_group_tags = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  cluster_tags = {
    Type      = "EKS-Cluster"
    ManagedBy = "DevOps"
  }

  # Remove all the aws-auth related arguments as they're not supported
  # create_aws_auth_configmap = true
  # manage_aws_auth_configmap = true
  # aws_auth_users = [...]
  # aws_auth_roles = [...]

  # EKS Managed Node Group configuration
  eks_managed_node_group_defaults = {
    instance_types = var.node_group_instance_types
    attach_cluster_primary_security_group = true
    enable_monitoring = true
  }

  eks_managed_node_groups = {
    main = {
      name = "${var.cluster_name}-node-group"

      instance_types = var.node_group_instance_types
      capacity_type  = "ON_DEMAND"
      
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      ami_type  = "AL2023_x86_64_STANDARD"
      disk_size = 50
      disk_type = "gp3"

      labels = {
        Environment = var.environment
        Project     = var.project_name
        NodeGroup   = "main"
      }

      tags = {
        Name        = "${var.cluster_name}-node-group"
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
      }
    }
  }
}


# Manual aws-auth ConfigMap management
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = module.eks.eks_managed_node_groups["main"].iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes",
        ]
      }
    ])

    mapUsers = yamlencode([
      {
        userarn  = data.aws_caller_identity.current.arn
        username = data.aws_caller_identity.current.user_id
        groups   = ["system:masters"]
      }
    ])
  }

  depends_on = [module.eks]
}
