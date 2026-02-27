## ==================== MAIN CONFIGURATION ====================
## Terraform configuration with EC2 instance, S3 bucket, and SNS notification services

## look up the current AWS account ID (used in SNS topic policy)
data "aws_caller_identity" "current" {}

## ==================== IAM SETUP ====================
## IAM allows the code running on EC2 to access S3, without hardcoding AWS credentials

resource "aws_iam_role" "ec2_instance_role" {
  name = "ds5220-dp1-ec2-role"

  ## need a trust policy for the instance role to be available
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

## ==================== S3 PERMISSIONS POLICY ====================

resource "aws_iam_role_policy" "s3_bucket_policy" {
  name = "DS5220-DP1-S3Access"
  role = aws_iam_role.ec2_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ds5220_dp1_bucket.arn,
          "${aws_s3_bucket.ds5220_dp1_bucket.arn}/*"
        ]
      }
    ]
  })
}

## ==================== SNS SUBSCRIBE POLICY ====================
## allows the EC2 instance to create an SNS subscription via `aws sns subscribe`

resource "aws_iam_role_policy" "sns_subscribe_policy" {
  name = "DS5220-DP1-SNSSubscribe"
  role = aws_iam_role.ec2_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Subscribe"
        ]
        Resource = [
          aws_sns_topic.ds5220_dp1_topic.arn
        ]
      }
    ]
  })
}

## ==================== INSTANCE PROFILE ====================
## instance profile is needed to apply the role ... which is needed to apply the policy (aka permissions)

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ds5220-dp1-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}

## ==================== SECURITY GROUP ====================
## security group to control network traffic allowed IN (i.e., ingress)

resource "aws_security_group" "ec2_security_group" {
  description = "Security group for EC2 instance - controls SSH and HTTP access"

  ## allow ssh from my_ip variable passed at deploy time
  ingress {
    description = "SSH from your IP only (secure remote access)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ## allow HTTP traffic on port 8000 from anywhere
  ingress {
    description = "Port 8000 (FastAPI app) accessible from anywhere"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ## allow all outbound traffic (default in CloudFormation security groups)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## ==================== ELASTIC IP ====================
## created standalone (no instance association) so EC2 UserData can reference it without circular dependency

resource "aws_eip" "elastic_ip" {
  domain = "vpc"
}

## ==================== SNS TOPIC ====================

resource "aws_sns_topic" "ds5220_dp1_topic" {
  name         = "ds5220-dp1"
  ## human-readable display name for console
  display_name = "DS5220 Data Project 1"
}

## ==================== SNS TOPIC POLICY ====================
## allow S3 to publish notifications to the SNS topic
## NOTE: uses hardcoded bucket ARN to avoid circular dependency with the bucket resource

resource "aws_sns_topic_policy" "sns_topic_policy" {
  arn = aws_sns_topic.ds5220_dp1_topic.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        ## grants to S3 service itself (not a user/role)
        Principal = {
          Service = "s3.amazonaws.com"
        }
        ## need to allow SNS:Publish so S3 can send notifications on upload
        Action   = "SNS:Publish"
        ## the Resource here is which SNS topic(s) can be published to
        Resource = aws_sns_topic.ds5220_dp1_topic.arn
        Condition = {
          ## require this is happening on my account
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ## restrict to the specific bucket (hardcoded to break circular dependency)
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.bucket_name}"
          }
        }
      }
    ]
  })
}

## ==================== EC2 INSTANCE ====================

resource "aws_instance" "ec2_instance" {
  ## ubuntu 24.04 AMI (found from previous reference architecture and verified in web console)
  ami           = "ami-0b6c6ebed2801a5cb"
  instance_type = "t3.micro"

  ## SSH key pair for remote access
  key_name = var.key_pair_name

  ## attach the IAM instance profile so the running instance has S3 permissions
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  ## associate security group defined elsewhere in the TF config
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  ## configure disk storage
  root_block_device {
    volume_size           = 16
    ## gp2 = general purpose
    volume_type           = "gp2"
    ## clean up and delete the disk when instance is terminated
    delete_on_termination = true
  }

  ## bootstrap!!
  ## the "hard way" ... using cloud init ... a little less legible but more sophisticated
  ## NOTE: templatefile() works like CloudFormation's !Sub ...
  ## ... it injects Terraform variables before cloud-init ever sees the config
  user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    bucket_name = var.bucket_name
    topic_arn   = aws_sns_topic.ds5220_dp1_topic.arn
    elastic_ip  = aws_eip.elastic_ip.public_ip
    aws_region  = var.aws_region
  }))

  ## ensure the SNS topic exists before the instance tries to subscribe
  depends_on = [
    aws_sns_topic.ds5220_dp1_topic,
    aws_eip.elastic_ip
  ]

  tags = {
    Name = "ds5220-dp1-instance"
  }
}

## ==================== ELASTIC IP ASSOCIATION ====================
## binds the EIP to the instance after both are created

resource "aws_eip_association" "eip_assoc" {
  allocation_id = aws_eip.elastic_ip.id
  instance_id   = aws_instance.ec2_instance.id
}

## ==================== SNS SUBSCRIPTION ====================
## declarative subscription so it's visible in the state and cleaned up on destroy
## the `aws sns subscribe` in UserData re-triggers confirmation while the app is running
## SNS deduplicates subscriptions to the same protocol + endpoint

resource "aws_sns_topic_subscription" "sns_http_subscription" {
  protocol  = "http"
  topic_arn = aws_sns_topic.ds5220_dp1_topic.arn
  endpoint  = "http://${aws_eip.elastic_ip.public_ip}:8000/notify"

  ## subscription confirmation is handled by the running app
  endpoint_auto_confirms = false
}

## ==================== S3 BUCKET ====================

resource "aws_s3_bucket" "ds5220_dp1_bucket" {
  ## NOTE: bucket name of course has to be globally unique (deployment will fail if this bucket exists)
  bucket = var.bucket_name

  ## ensure the SNS topic policy is in place before creating the bucket with notifications
  depends_on = [aws_sns_topic_policy.sns_topic_policy]
}

## ==================== S3 BUCKET NOTIFICATION ====================
## in plain English: notify SNS when a .csv file is uploaded to raw/ folder

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.ds5220_dp1_bucket.id

  topic {
    ## Send notification to our SNS topic
    topic_arn = aws_sns_topic.ds5220_dp1_topic.arn
    ## Trigger on any object creation (PutObject, CopyObject, etc.)
    events    = ["s3:ObjectCreated:*"]
    ## only files in the "raw/" prefix dir ending with ".csv"
    filter_prefix = "raw/"
    filter_suffix = ".csv"
  }

  depends_on = [aws_sns_topic_policy.sns_topic_policy]
}
