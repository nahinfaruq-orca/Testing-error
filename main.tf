provider "aws" {
  region = "us-east-1"
}

# Public S3 bucket, no encryption, no versioning, no logging
resource "aws_s3_bucket" "data" {
  bucket = "orca-demo-public-data-bucket"
}

resource "aws_s3_bucket_acl" "data" {
  bucket = aws_s3_bucket.data.id
  acl    = "public-read-write"
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Security group open to the world
resource "aws_security_group" "open" {
  name        = "wide-open"
  description = "Allow everything"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 with public IP, IMDSv1, unencrypted root volume, secret in user_data
resource "aws_instance" "web" {
  ami                         = "ami-0c55b159cbfafe1f0"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.open.id]

  metadata_options {
    http_tokens = "optional"
  }

  root_block_device {
    encrypted = false
  }

  user_data = <<-EOT
    #!/bin/bash
    export DB_PASSWORD=SuperSecret123!
  EOT
}

resource "aws_ebs_volume" "data" {
  availability_zone = "us-east-1a"
  size              = 20
  encrypted         = false
}

# Public, unencrypted RDS with hardcoded password and no backups
resource "aws_db_instance" "db" {
  identifier              = "orca-demo-db"
  engine                  = "mysql"
  engine_version          = "5.7"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = "admin"
  password                = "Password123!"
  publicly_accessible     = true
  storage_encrypted       = false
  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.open.id]
}

# Admin-everything IAM policy attached to a user with access keys
resource "aws_iam_policy" "admin" {
  name = "god-mode"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

resource "aws_iam_user" "svc" {
  name = "service-user"
}

resource "aws_iam_access_key" "svc" {
  user = aws_iam_user.svc.name
}

resource "aws_iam_user_policy_attachment" "svc" {
  user       = aws_iam_user.svc.name
  policy_arn = aws_iam_policy.admin.arn
}

# CloudTrail without log validation, single region, no KMS
resource "aws_cloudtrail" "trail" {
  name                          = "demo-trail"
  s3_bucket_name                = aws_s3_bucket.data.id
  enable_log_file_validation    = false
  is_multi_region_trail         = false
  include_global_service_events = false
}
