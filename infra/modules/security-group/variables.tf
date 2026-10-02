# modules/security-group/variables.tf

variable "name" {
  description = "Nome do Security Group"
  type        = string
}

variable "description" {
  description = "Descrição do Security Group"
  type        = string
  default     = "Managed by Terraform"
}

variable "vpc_id" {
  description = "ID da VPC onde o SG será criado"
  type        = string
}

variable "ingress_cidr_rules" {
  description = "Lista de regras de entrada com CIDR blocks"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

variable "ingress_sg_rule" {
  description = "Regra de entrada baseada em Source Security Group (opcional)"
  type = object({
    from_port    = number
    to_port      = number
    protocol     = string
    source_sg_id = string
    description  = string
  })
  default = null
}

variable "egress_rules" {
  description = "Lista de regras de saída"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound"
    }
  ]
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto para tags"
  type        = string
}
