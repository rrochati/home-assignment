terraform {
  backend "s3" {
    # Replace with your unique S3 bucket name
    bucket         = "your-terraform-state-bucket-name" 
    
    # This is the path to the state file inside the bucket
    key            = "home-stockholm/terraform.tfstate" 
    
    # The AWS region where your bucket and DynamoDB table are located
    region         = "eu-north-1" 
    
    # Replace with the name of your DynamoDB table for state locking
    dynamodb_table = "your-terraform-lock-table-name" 
    
    # Encrypt the state file at rest
    encrypt        = true
  }
}
