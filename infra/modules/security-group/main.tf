# modules/security-group/main.tf

resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  # ── Regras de entrada com CIDR ──────────────────────────────────────────
  dynamic "ingress" {
    for_each = var.ingress_cidr_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  # ── Regras de saída ────────────────────────────────────────────────────
  dynamic "egress" {
    for_each = var.egress_rules
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      description = egress.value.description
    }
  }

  tags = {
    Name        = var.name
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── Regra de entrada com Source Security Group (opcional) ──────────────────
resource "aws_security_group_rule" "ingress_sg" {
  count = var.ingress_sg_rule != null ? 1 : 0

  type                     = "ingress"
  from_port                = var.ingress_sg_rule.from_port
  to_port                  = var.ingress_sg_rule.to_port
  protocol                 = var.ingress_sg_rule.protocol
  source_security_group_id = var.ingress_sg_rule.source_sg_id
  description              = var.ingress_sg_rule.description
  security_group_id        = aws_security_group.this.id
}
