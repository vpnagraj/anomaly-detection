## ==================== OUTPUTS ====================
## values to be displayed after stack creation
## retrieve via: terraform output

output "elastic_ip_address" {
  description = "The public Elastic IP address of the EC2 instance"
  value       = aws_eip.elastic_ip.public_ip
}

output "ec2_instance_id" {
  description = "The EC2 Instance ID to identify the instance in the console"
  value       = aws_instance.ec2_instance.id
}

output "s3_bucket_name" {
  description = "The S3 bucket name"
  value       = aws_s3_bucket.ds5220_dp1_bucket.id
}

output "sns_topic_arn" {
  description = "The SNS topic ARN"
  value       = aws_sns_topic.ds5220_dp1_topic.arn
}

output "security_group_id" {
  description = "The security group ID to control ingress to the instance"
  value       = aws_security_group.ec2_security_group.id
}
