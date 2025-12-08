.PHONY: init plan apply-plan apply validate fmt lint kubeconfig check-keda deploy-nginx check-nginx send-test-messages purge-queue cleanup-nginx destroy

# Initialize Terraform
init:
	terraform init

# Plan Terraform changes
plan:
	terraform plan -var-file="terraform.tfvars"  -out=tfplan

# Apply from saved plan
apply-plan:
	terraform apply tfplan
	rm -f tfplan

# Apply Terraform changes
apply:
	terraform apply -var-file="terraform.tfvars" -auto-approve

# Validate Terraform configuration
validate:
	terraform validate

# Format Terraform files
fmt:
	terraform fmt -recursive

# Lint with tflint (requires tflint to be installed)
lint:
	tflint --init
	tflint

# Get kubectl config
kubeconfig:
	aws eks update-kubeconfig --region $(shell terraform output -raw aws_region) --name $(shell terraform output -raw cluster_name)

# Check KEDA installation
check-keda:
	kubectl get pods -n keda

# Deploy nginx with KEDA scaling
deploy-nginx:
	@echo "Deploying nginx with KEDA autoscaling..."
	# Apply namespace first
	envsubst < k8s-manifests/namespace.yaml | kubectl apply -f -
	# Then deploy other resources
	@SQS_QUEUE_URL=$$(terraform output -raw sqs_queue_url) && \
	AWS_REGION=$$(terraform output -raw aws_region) && \
	KEDA_IRSA_ROLE_ARN=$$(terraform output -raw keda_irsa_role_arn) && \
	NAMESPACE=$$(terraform output -raw webapp_namespace) && \
	if [ -z "$$SQS_QUEUE_URL" ] || [ -z "$$AWS_REGION" ] || [ -z "$$KEDA_IRSA_ROLE_ARN" ] || [ -z "$$NAMESPACE" ]; then \
	    echo "Error: Missing required Terraform outputs"; \
	    exit 1; \
	fi && \
	echo "Using SQS Queue: $$SQS_QUEUE_URL" && \
	echo "Using AWS Region: $$AWS_REGION" && \
	echo "Using KEDA Role: $$KEDA_IRSA_ROLE_ARN" && \
	echo "Using Namespace: $$NAMESPACE" && \
	export SQS_QUEUE_URL="$$SQS_QUEUE_URL" && \
	export AWS_REGION="$$AWS_REGION" && \
	export KEDA_IRSA_ROLE_ARN="$$KEDA_IRSA_ROLE_ARN" && \
	export NAMESPACE="$$NAMESPACE" && \
	envsubst < k8s-manifests/nginx-deployment.yaml | kubectl apply -f - && \
	envsubst < k8s-manifests/service-account.yaml | kubectl apply -f - && \
	envsubst < k8s-manifests/keda-scaledobject.yaml | kubectl apply -f - 

# Check nginx deployment status
check-nginx:
	@echo "Checking nginx deployment..."
	kubectl get deployment nginx-deployment
	kubectl get svc nginx-service
	kubectl get pods -l app=nginx
	kubectl get scaledobject nginx-sqs-scaler
	kubectl get hpa

# Send test messages to SQS to trigger scaling
send-test-messages:
	@echo "Sending test messages to SQS queue..."
	@SQS_QUEUE_URL=$$(terraform output -raw sqs_queue_url) && \
	echo "Using queue URL: $$SQS_QUEUE_URL" && \
	for i in {1..10}; do \
	    aws sqs send-message --queue-url "$$SQS_QUEUE_URL" --message-body "Test message $$i for KEDA scaling" && \
	    echo "Sent message $$i"; \
	done
	@echo "Sent 10 test messages. Check scaling with: make check-nginx"

# Purge all messages from SQS queue
purge-queue:
	@echo "Purging all messages from SQS queue..."
	@SQS_QUEUE_URL=$$(terraform output -raw sqs_queue_url) && \
	if [ -z "$$SQS_QUEUE_URL" ]; then \
	    echo "Error: SQS queue URL not found"; \
	    exit 1; \
	fi && \
	echo "Purging queue: $$SQS_QUEUE_URL" && \
	aws sqs purge-queue --queue-url "$$SQS_QUEUE_URL" && \
	echo "Queue purged successfully. It may take up to 60 seconds for the purge to complete." && \
	echo "Check scaling down with: make check-nginx"


# Clean up nginx deployment
cleanup-nginx:
	kubectl delete scaledobject nginx-sqs-scaler
	kubectl delete deployment nginx-deployment
	kubectl delete service nginx-service
	kubectl delete serviceaccount keda-nginx-sa
	kubectl delete triggerauthentication keda-trigger-auth-aws-credentials

# Destroy infrastructure
destroy:
	terraform destroy -var-file="terraform.tfvars" -auto-approve

# Apply infrastructure without aws-auth issues
apply-infra-clean:
	terraform apply -var-file="terraform.tfvars" -target=module.vpc -target=module.eks -target=aws_sqs_queue.keda_queue -target=module.keda_irsa -auto-approve
	@echo "Infrastructure applied. Updating kubeconfig..."
	make kubeconfig

# Manual aws-auth fix using template file
fix-aws-auth:
	@echo "Fixing aws-auth ConfigMap for kubectl access..."
	@USER_ARN=$$(aws sts get-caller-identity --query Arn --output text) && \
	USER_ID=$$(aws sts get-caller-identity --query UserId --output text | cut -d: -f2) && \
	NODE_ROLE_ARN=$$(aws iam list-roles --query "Roles[?contains(RoleName, 'node-group')].Arn" --output text) && \
	echo "User ARN: $$USER_ARN" && \
	echo "User ID: $$USER_ID" && \
	echo "Node Role ARN: $$NODE_ROLE_ARN" && \
	export USER_ARN="$$USER_ARN" && \
	export USER_ID="$$USER_ID" && \
	export NODE_ROLE_ARN="$$NODE_ROLE_ARN" && \
	envsubst < k8s-manifests/aws-auth-template.yaml | kubectl apply -f -

# Complete deployment with auth fix
deploy-with-auth:
	@echo "=== Step 1: Deploy Infrastructure ==="
	make apply-infra-clean
	@echo ""
	@echo "=== Step 2: Wait for cluster readiness ==="
	sleep 30
	@echo ""
	@echo "=== Step 3: Fix authentication ==="
	make fix-aws-auth
	@echo ""
	@echo "=== Step 4: Test kubectl access ==="
	kubectl get nodes || echo "Still having auth issues..."
	@echo ""
	@echo "=== Step 5: Deploy remaining resources ==="
	terraform apply -var-file="terraform.tfvars" -auto-approve