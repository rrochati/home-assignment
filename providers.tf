

provider "aws" {
  region = var.aws_region

  default_tags {
	tags = local.common_tags
  }

  # Add this block to ignore automatic AWS tags
  ignore_tags {
	keys = ["CreatedAt", "CreatedBy", "Environment", "ManagedBy"]
  }
}

# Get EKS cluster information
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  
  depends_on = [module.eks]
}

# Configure Kubernetes provider with proper error handling
provider "kubernetes" {
  host                   = try(module.eks.cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")

  exec {
	api_version = "client.authentication.k8s.io/v1beta1"
	command     = "aws"
	args = [
	  "eks",
	  "get-token",
	  "--cluster-name",
	  try(module.eks.cluster_name, ""),
	]
  }
}

provider "helm" {
  kubernetes {
	host                   = try(module.eks.cluster_endpoint, "")
	cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")

	exec {
	  api_version = "client.authentication.k8s.io/v1beta1"
	  command     = "aws"
	  args = [
	    "eks",
	    "get-token",
	    "--cluster-name",
	    try(module.eks.cluster_name, ""),
	  ]
	}
  }
}