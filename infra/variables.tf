# infra/variables.tf

variable "region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nome do projeto — usado em tags e nomes de recursos"
  type        = string
  default     = "reservas-api"
}

variable "environment" {
  description = "Ambiente de provisionamento"
  type        = string
  default     = "production"
}

# ── Banco de dados ─────────────────────────────────────────────────────────
variable "db_name" {
  description = "Nome do banco de dados PostgreSQL"
  type        = string
  default     = "reservasdb"
}

variable "db_username" {
  description = "Usuário master do banco de dados PostgreSQL"
  type        = string
  default     = "reservas"
}

variable "db_password" {
  description = "Senha master do banco de dados PostgreSQL (mínimo 8 caracteres alfanuméricos)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{8,}$", var.db_password))
    error_message = "A senha deve conter apenas caracteres alfanuméricos e ter no mínimo 8 caracteres."
  }
}

# ── EC2 / repositório ──────────────────────────────────────────────────────
variable "key_name" {
  description = "Nome do key pair EC2 (ex: vockey — disponível no AWS Academy)"
  type        = string
  default     = "vockey"
}

variable "repo_url" {
  description = "URL HTTPS do repositório Git da API (ex: https://github.com/usuario/repo)"
  type        = string
}

variable "repo_branch" {
  description = "Branch do repositório a ser clonada"
  type        = string
  default     = "main"
}

# ── Rede ───────────────────────────────────────────────────────────────────
variable "allowed_cidr" {
  description = "CIDR liberado para SSH (22) e API (3000) na EC2. Padrão: aberto (ajuste em produção)."
  type        = string
  default     = "0.0.0.0/0"
}
