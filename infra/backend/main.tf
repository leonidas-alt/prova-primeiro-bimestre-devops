terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project = "reservas-api"
      Owner   = var.ra
      Env     = "backend"
    }
  }
}

variable "ra" {
  description = "Número de RA do aluno — usado no nome do bucket S3"
  type        = string
}

# ── S3 Bucket criado via AWS CLI (evita s3:GetBucketObjectLockConfiguration) ─
resource "null_resource" "s3_bucket" {
  triggers = {
    bucket_name = "technova-tfstate-${var.ra}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3api create-bucket \
        --bucket technova-tfstate-${var.ra} \
        --region us-east-1 2>/dev/null || true

      aws s3api put-bucket-versioning \
        --bucket technova-tfstate-${var.ra} \
        --versioning-configuration Status=Enabled

      aws s3api put-bucket-encryption \
        --bucket technova-tfstate-${var.ra} \
        --server-side-encryption-configuration '{
          "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
              "SSEAlgorithm": "AES256"
            }
          }]
        }'

      aws s3api put-public-access-block \
        --bucket technova-tfstate-${var.ra} \
        --public-access-block-configuration '{
          "BlockPublicAcls": true,
          "IgnorePublicAcls": true,
          "BlockPublicPolicy": true,
          "RestrictPublicBuckets": true
        }'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws s3 rb s3://${self.triggers.bucket_name} --force 2>/dev/null || true
    EOT
  }
}

# ── DynamoDB para lock do state ──────────────────────────────────────────────
resource "aws_dynamodb_table" "tf_lock" {
  name         = "technova-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "technova-tf-lock"
  }
}

output "s3_bucket_name" {
  description = "Nome do bucket S3 do remote state"
  value       = "technova-tfstate-${var.ra}"
}

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB para locking"
  value       = aws_dynamodb_table.tf_lock.name
}
