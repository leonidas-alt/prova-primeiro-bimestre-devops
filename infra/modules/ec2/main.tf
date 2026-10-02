# modules/ec2/main.tf

# ── AMI Amazon Linux 2023 (us-east-1) ─────────────────────────────────────
# Fixado na versão mais recente de AL2023 disponível no Academy.
# Se precisar de outra região, atualize o ami_id na variável.
data "aws_ami" "al2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
  ami = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023[0].id

  # Script que instala Node.js 20, clona o repo e sobe a API como systemd service
  user_data_script = <<-SCRIPT
    #!/bin/bash
    set -euo pipefail
    exec > /var/log/user-data.log 2>&1

    # ── 1. Atualizar pacotes e instalar git ───────────────────────────────
    dnf update -y
    dnf install -y git
    # curl-minimal já vem instalado no AL2023 — não instalar curl (conflito)

    # ── 2. Instalar Node.js 20 via NodeSource ────────────────────────────
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs --allowerasing

    # ── 3. Clonar o repositório ────────────────────────────────────────────
    git clone --branch ${var.repo_branch} ${var.repo_url} /opt/reservas-api
    cd /opt/reservas-api/app
    npm ci --omit=dev

    # ── 4. Criar arquivo de ambiente ──────────────────────────────────────
    # O endpoint do RDS vem no formato host:port — separamos o host
    RDS_HOST=$(echo "${var.rds_endpoint}" | cut -d: -f1)

    cat > /opt/reservas-api/app/.env <<EOF
    NODE_ENV=production
    PORT=3000
    POSTGRES_USER=${var.db_username}
    POSTGRES_PASSWORD=${var.db_password}
    POSTGRES_DB=${var.db_name}
    DB_HOST=$${RDS_HOST}
    DB_PORT=5432
    DB_SSL=true
    EOF

    # ── 5. Criar serviço systemd ──────────────────────────────────────────
    cat > /etc/systemd/system/reservas-api.service <<EOF
    [Unit]
    Description=TechNova Reservas API
    After=network.target

    [Service]
    Type=simple
    WorkingDirectory=/opt/reservas-api/app
    EnvironmentFile=/opt/reservas-api/app/.env
    ExecStart=/usr/bin/node src/index.js
    Restart=on-failure
    RestartSec=5
    StandardOutput=journal
    StandardError=journal

    [Install]
    WantedBy=multi-user.target
    EOF

    systemctl daemon-reload
    systemctl enable reservas-api
    systemctl start reservas-api

    echo "user-data concluído com sucesso."
  SCRIPT
}

# ── Instância EC2 ──────────────────────────────────────────────────────────
resource "aws_instance" "this" {
  ami                         = local.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = true

  user_data                   = local.user_data_script
  user_data_replace_on_change = true

  tags = {
    Name        = var.instance_name
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}
