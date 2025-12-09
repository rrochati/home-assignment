module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"  # Compatible with AWS provider ~> 5.0

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # Use single NAT gateway to avoid EIP limits
  enable_nat_gateway = true
  single_nat_gateway = true  # This uses only 1 EIP instead of 3
  
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Alternative: Disable NAT gateways entirely if outbound internet isn't needed
  # enable_nat_gateway = false

  tags = {
	"kubernetes.io/cluster/${var.cluster_name}" = "shared"
	Environment = var.environment
	ManagedBy   = "Terraform"
  }

  public_subnet_tags = {
	"kubernetes.io/cluster/${var.cluster_name}" = "shared"
	"kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
	"kubernetes.io/cluster/${var.cluster_name}" = "shared"
	"kubernetes.io/role/internal-elb"           = "1"
  }
}