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
	@if terraform output aws_region > /dev/null 2>&1; then \
	    aws eks update-kubeconfig --region $$(terraform output -raw aws_region) --name $$(terraform output -raw cluster_name); \
	else \
	    echo "Terraform outputs not available, using values from terraform.tfvars..."; \
	    aws eks update-kubeconfig --region us-east-1 --name ha-eks; \
	fi

# Check KEDA installation
check-keda:
	kubectl get pods -n keda

# Deploy nginx with KEDA scaling
deploy-nginx:
	@echo "Deploying nginx with KEDA autoscaling..."
	@echo "Getting Terraform outputs..."
	@SQS_QUEUE_URL=$$(terraform output -raw sqs_queue_url 2>/dev/null || echo "") && \
	AWS_REGION=$$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1") && \
	KEDA_IRSA_ROLE_ARN=$$(terraform output -raw keda_irsa_role_arn 2>/dev/null || echo "") && \
	NAMESPACE="webapp" && \
	echo "SQS Queue URL: $$SQS_QUEUE_URL" && \
	echo "AWS Region: $$AWS_REGION" && \
	echo "KEDA IRSA Role: $$KEDA_IRSA_ROLE_ARN" && \
	echo "Namespace: $$NAMESPACE" && \
	if [ -z "$$SQS_QUEUE_URL" ]; then \
	    echo "Warning: SQS_QUEUE_URL is empty"; \
	fi && \
	if [ -z "$$KEDA_IRSA_ROLE_ARN" ]; then \
	    echo "Warning: KEDA_IRSA_ROLE_ARN is empty"; \
	fi && \
	export SQS_QUEUE_URL="$$SQS_QUEUE_URL" && \
	export AWS_REGION="$$AWS_REGION" && \
	export KEDA_IRSA_ROLE_ARN="$$KEDA_IRSA_ROLE_ARN" && \
	export NAMESPACE="$$NAMESPACE" && \
	echo "Creating namespace $$NAMESPACE..." && \
	envsubst < k8s-manifests/namespace.yaml | kubectl apply -f - && \
	echo "Deploying nginx..." && \
	envsubst < k8s-manifests/nginx-deployment.yaml | kubectl apply -f - && \
	echo "Creating service account..." && \
	envsubst < k8s-manifests/service-account.yaml | kubectl apply -f - && \
	echo "Creating KEDA scaled object..." && \
	envsubst < k8s-manifests/keda-scaledobject.yaml | kubectl apply -f - && \
	echo "Deployment completed!"

# Check nginx deployment status
check-nginx:
	@echo "Checking nginx deployment..."
	@NAMESPACE="webapp" && \
	kubectl get deployment nginx-deployment -n $$NAMESPACE && \
	kubectl get svc nginx-service -n $$NAMESPACE && \
	kubectl get pods -l app=nginx -n $$NAMESPACE && \
	kubectl get scaledobject nginx-sqs-scaler -n $$NAMESPACE && \
	kubectl get hpa -n $$NAMESPACE

# Send test messages to SQS to trigger scaling
send-test-messages:
	@echo "Sending test messages to SQS queue..."
	@SQS_QUEUE_URL=$$(terraform output -raw sqs_queue_url 2>/dev/null) && \
	if [ -z "$$SQS_QUEUE_URL" ]; then \
	    echo "Error: Could not get SQS queue URL from Terraform outputs"; \
	    exit 1; \
	fi && \
	echo "Using queue URL: $$SQS_QUEUE_URL" && \
	for i in {1..10}; do \
	    aws sqs send-message --queue-url "$$SQS_QUEUE_URL" --message-body "Test message $$i for KEDA scaling" && \
	    echo "Sent message $$i"; \
	done && \
	echo "Sent 10 test messages. Check scaling with: make check-nginx"

# Purge all messages from SQS queue
purge-queue:
	@echo "Purging all messages from SQS queue..."
	@SQS_QUEUE_URL=$$(terraform output -raw sqs_queue_url 2>/dev/null) && \
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
	@NAMESPACE="webapp" && \
	kubectl delete scaledobject nginx-sqs-scaler -n $$NAMESPACE --ignore-not-found=true && \
	kubectl delete deployment nginx-deployment -n $$NAMESPACE --ignore-not-found=true && \
	kubectl delete service nginx-service -n $$NAMESPACE --ignore-not-found=true && \
	kubectl delete serviceaccount keda-nginx-sa -n $$NAMESPACE --ignore-not-found=true && \
	kubectl delete triggerauthentication keda-trigger-auth-aws-credentials -n $$NAMESPACE --ignore-not-found=true && \
	kubectl delete namespace $$NAMESPACE --ignore-not-found=true

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

# Alternative approach without envsubst
deploy-nginx-direct:
	@echo "Deploying nginx with hardcoded values..."
	kubectl create namespace webapp --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f k8s-manifests/nginx-deployment.yaml
	kubectl apply -f k8s-manifests/service-account.yaml
	kubectl apply -f k8s-manifests/keda-scaledobject.yaml