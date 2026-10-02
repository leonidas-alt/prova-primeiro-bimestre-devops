terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ── Backend S3 para Remote State ────────────────────────────────────────
  # ATENÇÃO: substitua o valor de "bucket" pelo nome real gerado em infra/backend.
  # Exemplo: depois de rodar "terraform apply" em infra/backend com -var="ra=12345",
  # o bucket criado será "technova-tfstate-12345". Atualize abaixo.
  backend "s3" {
    bucket         = "technova-tfstate-4023575"
    key            = "reservas/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "technova-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "reservas-api"
      ManagedBy = "terraform"
      Owner     = "DevOps-ADS"
    }
  }
}
