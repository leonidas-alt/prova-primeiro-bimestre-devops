# modules/ec2/variables.tf

variable "instance_name" {
  description = "Nome da instância EC2 (tag Name)"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "ID da AMI. Se vazio, busca a Amazon Linux 2023 mais recente automaticamente."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "ID da subnet pública onde a instância será criada"
  type        = string
}

variable "security_group_ids" {
  description = "Lista de IDs dos Security Groups associados à instância"
  type        = list(string)
}

variable "key_name" {
  description = "Nome do key pair EC2 para acesso SSH (ex: vockey)"
  type        = string
}

variable "iam_instance_profile" {
  description = "Nome do Instance Profile IAM (use LabInstanceProfile no AWS Academy)"
  type        = string
  default     = "LabInstanceProfile"
}

variable "repo_url" {
  description = "URL do repositório Git da API (HTTPS)"
  type        = string
}

variable "repo_branch" {
  description = "Branch do repositório a clonar"
  type        = string
  default     = "main"
}

variable "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL (host:port)"
  type        = string
}

variable "db_name" {
  description = "Nome do banco de dados PostgreSQL"
  type        = string
}

variable "db_username" {
  description = "Usuário do banco de dados PostgreSQL"
  type        = string
}

variable "db_password" {
  description = "Senha do banco de dados PostgreSQL"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto para tags"
  type        = string
}
