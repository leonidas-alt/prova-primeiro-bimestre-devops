# infra/main.tf
# Composição dos módulos: VPC → Security Groups → RDS → EC2

# ── VPC com subnets públicas e privadas em 2 AZs ───────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project
  environment  = var.environment
  vpc_cidr     = "10.0.0.0/16"

  subnets = {
    public-1a = {
      cidr = "10.0.1.0/24"
      az   = "us-east-1a"
      type = "public"
    }
    public-1b = {
      cidr = "10.0.2.0/24"
      az   = "us-east-1b"
      type = "public"
    }
    private-1a = {
      cidr = "10.0.11.0/24"
      az   = "us-east-1a"
      type = "private"
    }
    private-1b = {
      cidr = "10.0.12.0/24"
      az   = "us-east-1b"
      type = "private"
    }
  }
}

# ── Security Group da EC2 (SSH + porta 3000) ───────────────────────────────
module "sg_ec2" {
  source = "./modules/security-group"

  name         = "${var.project}-${var.environment}-ec2-sg"
  description  = "SG da instancia EC2 - permite SSH e acesso a API"
  vpc_id       = module.vpc.vpc_id
  project_name = var.project
  environment  = var.environment

  ingress_cidr_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.allowed_cidr]
      description = "SSH"
    },
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = [var.allowed_cidr]
      description = "API Node.js"
    }
  ]
}

# ── Security Group do RDS (5432 somente do SG da EC2) ─────────────────────
module "sg_rds" {
  source = "./modules/security-group"

  name         = "${var.project}-${var.environment}-rds-sg"
  description  = "SG do RDS - permite PostgreSQL apenas do SG da EC2"
  vpc_id       = module.vpc.vpc_id
  project_name = var.project
  environment  = var.environment

  ingress_sg_rule = {
    from_port    = 5432
    to_port      = 5432
    protocol     = "tcp"
    source_sg_id = module.sg_ec2.sg_id
    description  = "PostgreSQL do SG da EC2"
  }
}

# ── RDS PostgreSQL nas subnets privadas ────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  project_name       = var.project
  environment        = var.environment
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.sg_rds.sg_id]
  instance_class     = "db.t3.micro"
}

# ── EC2 na subnet pública com a API ───────────────────────────────────────
module "ec2" {
  source = "./modules/ec2"

  instance_name        = "${var.project}-${var.environment}-api"
  project_name         = var.project
  environment          = var.environment
  instance_type        = "t2.micro"
  ami_id               = ""   # deixa o módulo buscar AL2023 automaticamente
  subnet_id            = module.vpc.public_subnet_ids[0]
  security_group_ids   = [module.sg_ec2.sg_id]
  key_name             = var.key_name
  iam_instance_profile = "LabInstanceProfile"

  # Configurações para o user_data instalar e subir a API
  repo_url     = var.repo_url
  repo_branch  = var.repo_branch
  rds_endpoint = module.rds.db_endpoint
  db_name      = var.db_name
  db_username  = var.db_username
  db_password  = var.db_password
}
