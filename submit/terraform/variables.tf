## ==================== VARIABLES ====================
## specify variables when deploying ...
## example: terraform apply -var="my_ip=203.0.113.42/32" -var="key_pair_name=my-key"
## or define them in a terraform.tfvars file

variable "my_ip" {
  type        = string
  description = "IP address or CIDR block for SSH access (e.g., 203.0.113.42/32 for single IP, 203.0.113.0/24 for subnet)"

  ## gnarly regex for constraint
  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}(/\\d{1,2})?$", var.my_ip))
    error_message = "Must be a valid IP address or CIDR block. Example: 192.168.1.100/32 or 10.0.0.0/8"
  }
}

variable "key_pair_name" {
  type        = string
  description = "Name of an existing EC2 key pair for SSH access"
}

variable "bucket_name" {
  type        = string
  default     = "vpn7n-ds5220-dp1"
  description = "Globally unique S3 bucket name"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy resources in"
}
