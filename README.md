# Home Assignment EKS Infrastructure

This Terraform project creates an AWS EKS cluster with KEDA addon for autoscaling an webapp (nginx) based on SQS queue metrics.

## Architecture

- **EKS Cluster**: Kubernetes 1.32 cluster
- **Node Group**: 2 on-demand EC2 instances (t3.medium)
- **VPC**: Standard VPC with 3 availability zones
- **KEDA**: Kubernetes Event-driven Autoscaler connected to AWS SQS
- **SQS**: Queue for triggering autoscaling events

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl
- Helm (optional, for manual KEDA management)

## Deployment

1. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars` with your specific values**


3. Run `aws configure` or export the env variables:
   ```bash
   export AWS_ACCESS_KEY_ID="your-access-key-id"
   export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

4. **Initialize and apply Terraform:**
   ```bash
   # Initial setup
   make init

   # Plan and apply
   make plan          # Review changes
   make apply-plan    # Apply changes from file plan
   make apply         # Apply changes
   ```

5. **Configure kubectl:**
   ```bash
   make kubeconfig
   ```

6. **Verify KEDA installation:**
   ```bash
   make check-keda
   ```

7. Deploy and check nginx
   ```bash
   make deploy-nginx    # Deploy nginx

   make check-nginx     # Check nignx status
   ```

## Usage

- Check nginx status
   ```bash
   make check-nginx
   ```

- Send test messages to SQS to trigger scaling
   ```bash
   make send-test-messages
   ```

- Check nginx status again
   ```bash
   make check-nginx
   ```

- Purge SQS queue to scale down
   ```bash
   make purge-queue
   ```

- Check nginx status again (it can take a few minutes to scale down)
   ```bash
   make check-nginx
   ```

### Accessing Resources

- **EKS Cluster**: Use kubectl with the configured context
- **SQS Queue**: Available at the URL from `terraform output sqs_queue_url`

## Security

- IRSA (IAM Roles for Service Accounts) is used for secure AWS API access
- Node groups are deployed in private subnets

## Monitoring

- CloudWatch metrics are automatically available for EKS and SQS
- KEDA provides metrics for scaling decisions

## Cleanup

   ```bash
   make cleanup-nginx   # Remove kubernetes objects
   make destroy         # Destroy infrastructure
   ```

## Troubleshooting

- Check KEDA logs: `kubectl logs -n keda deployment/keda-operator`
- Verify IRSA configuration: `kubectl describe sa keda-operator -n keda`
- Check SQS permissions: Review the queue policy in AWS Console

## To do:
[ ] Add safety confirm for cleanup steps
[ ] Improve files and folder structure
[ ] Improve security
   -  Adjust user role and security groups to follow least privilege principle
[ ] Fine tune scaling up and down for a more progressive behavior
[ ] Upgrade kubernetes version
