# Terraform: EC2 + S3 + SNS Anomaly Detection Stack

Terraform configuration that deploys an EC2 instance running a FastAPI anomaly detection app, an S3 bucket with event notifications, and SNS for pub/sub messaging. This is a direct conversion of the original CloudFormation template — identical behavior, same resources, same bootstrap logic.

## Architecture

- **EC2 Instance** (`t3.micro`, Ubuntu 24.04) — runs the FastAPI app via systemd
- **Elastic IP** — static public IP for the instance
- **S3 Bucket** — triggers SNS notifications when `.csv` files are uploaded to `raw/`
- **SNS Topic** — relays S3 event notifications to the FastAPI `/notify` endpoint
- **IAM Role + Policies** — grants EC2 access to S3 and SNS (no hardcoded credentials)
- **Security Group** — SSH from your IP only, port 8000 open to the world

## Prerequisites

1. **Terraform** installed (>= 1.0): https://developer.hashicorp.com/terraform/install
2. **AWS CLI** configured with credentials (`aws configure`)
3. **EC2 Key Pair** already created in your target region

## File Structure

```
.
├── providers.tf              # AWS provider and Terraform version constraints
├── variables.tf              # Input variables (equivalent to CF Parameters)
├── main.tf                   # All resources (IAM, EC2, S3, SNS, Security Group)
├── cloud-init.yaml           # Cloud-init template for EC2 bootstrap
├── outputs.tf                # Output values displayed after deployment
├── terraform.tfvars.example  # Example variable values (copy to terraform.tfvars)
└── README.md                 # This file
```

## Deployment Instructions

NOTE: We have a step to configure the variables. This is just for future reference when working on stacks that might have many more variables. All examples below show how to use run the terraform steps using variables passed inline.

### Step 1: Configure Variables

```bash
## copy the example terraform.tfvars file

## edit with your values
## - my_ip: your public IP for SSH access (find it with: curl ifconfig.me)
## - key_pair_name: name of your existing EC2 key pair
## - bucket_name: globally unique S3 bucket name
## - aws_region: AWS region to deploy in
vim terraform.tfvars
```

### Step 2: Initialize Terraform

```bash
## downloads the AWS provider plugin and sets up the working directory
## equivalent to nothing in CF — CF handles this automatically
terraform init
```

### Step 3: Preview Changes (Dry Run)

```bash
## shows what resources will be created/modified/destroyed
## equivalent to: aws cloudformation create-change-set
terraform plan \
  -var="my_ip=203.0.113.42/32" \
  -var="key_pair_name=ds5220-key" \
  -var="bucket_name=vpn7n-ds5220-dp1" \
  -var="aws_region=us-east-1"
```

### Step 4: Deploy

```bash
## creates all resources
## equivalent to: aws cloudformation create-stack --parameters ParameterKey=MyIP,ParameterValue=203.0.113.42/32
terraform apply \
  -var="my_ip=203.0.113.42/32" \
  -var="key_pair_name=ds5220-key" \
  -var="bucket_name=vpn7n-ds5220-dp1" \
  -var="aws_region=us-east-1"
```

Terraform will show the plan and prompt for confirmation. Type `yes` to proceed.

### Step 5: View Outputs

```bash
## display all output values
## equivalent to: aws cloudformation describe-stacks --query 'Stacks[0].Outputs'
terraform output

## get a specific output
terraform output elastic_ip_address
```

### Step 6: SSH into the Instance

```bash
ssh -i /path/to/your-key.pem ubuntu@$(terraform output -raw elastic_ip_address)
```

### Step 7: Check Cloud-Init Logs (Debugging)

```bash
## on the EC2 instance, check bootstrap progress/errors
tail -f /var/log/cloud-init-output.log

## check the FastAPI systemd service status
sudo systemctl status fastapi-app.service

## view FastAPI app logs
sudo journalctl -u fastapi-app.service -f
```

### Step 8: Destroy (Tear Down)

```bash
## destroys all resources created by this config
## equivalent to: aws cloudformation delete-stack
terraform destroy
```

Auto-approve (skip confirmation):

```bash
terraform destroy -auto-approve
```

## Other Useful Commands

```bash
## show current state of deployed resources
terraform show

## list all resources in state
terraform state list

## refresh state from AWS (detect drift)
terraform refresh

## format all .tf files
terraform fmt

## validate configuration syntax
terraform validate

## force recreation of a specific resource (e.g., to re-run cloud-init)
terraform apply -replace="aws_instance.ec2_instance"
```

## CloudFormation vs Terraform Mapping

| CloudFormation | Terraform |
|---|---|
| `Parameters` | `variables.tf` |
| `!Ref`, `!Sub`, `!GetAtt` | resource references, `templatefile()` |
| `Fn::Base64` + `UserData` | `base64encode()` + `user_data` |
| `DependsOn` | `depends_on` (implicit in most cases) |
| `Outputs` + `Export` | `outputs.tf` |
| `aws cloudformation create-stack` | `terraform apply` |
| `aws cloudformation delete-stack` | `terraform destroy` |
| `aws cloudformation describe-stacks` | `terraform output` / `terraform show` |