# API de Reservas — TechNova

**Aluno:** NOME COMPLETO  
**RA:** SEU-RA  
**Disciplina:** DevOps — ADS 2026.2  
**Professor:** Alexandre da Costa Tavares Jr

---

## Descrição

API RESTful de gerenciamento de reservas construída com Node.js 20 + Express + PostgreSQL.
O projeto cobre a jornada completa de DevOps: versionamento Git, containerização com Docker,
orquestração local com Docker Compose e infraestrutura na AWS provisionada com Terraform modularizado.

---

## Estrutura do Projeto

```
prova-primeiro-bimestre-devops/
├── app/                    # API Node.js
│   ├── src/
│   │   ├── index.js
│   │   ├── db.js
│   │   └── routes/reservas.js
│   ├── package.json
│   ├── Dockerfile
│   └── .dockerignore
├── docker-compose.yml      # Ambiente local (API + PostgreSQL)
├── .env.example
├── .gitignore
├── infra/                  # Terraform modularizado
│   ├── backend/            # S3 + DynamoDB (remote state)
│   ├── modules/
│   │   ├── vpc/
│   │   ├── security-group/
│   │   ├── rds/
│   │   └── ec2/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
├── evidencias/             # Outputs dos comandos de validação
└── relatorio.md
```

---

## Rotas da API

| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/reservas` | Cria uma reserva (campos: `cliente`, `data`) |
| `GET` | `/reservas` | Lista todas as reservas |
| `GET` | `/reservas/:id` | Busca uma reserva pelo ID |
| `PUT` | `/reservas/:id` | Atualiza uma reserva |
| `DELETE` | `/reservas/:id` | Remove uma reserva (204) |
| `GET` | `/health` | Health check |

---

## Ambiente Local (Docker Compose)

### Pré-requisitos
- Docker e Docker Compose instalados

### Subir o ambiente

```bash
# 1. Copiar e preencher o .env
cp .env.example .env
# Edite .env: adicione POSTGRES_PASSWORD=<sua_senha>

# 2. Subir os serviços
docker compose up -d

# 3. Verificar
docker compose ps
curl http://localhost:3000/health
```

### Testar as rotas

```bash
# Criar reserva
curl -s -X POST http://localhost:3000/reservas \
  -H "Content-Type: application/json" \
  -d '{"cliente":"Maria Silva","data":"2026-11-01"}' | jq

# Listar reservas
curl -s http://localhost:3000/reservas | jq

# Buscar por ID
curl -s http://localhost:3000/reservas/1 | jq

# Atualizar
curl -s -X PUT http://localhost:3000/reservas/1 \
  -H "Content-Type: application/json" \
  -d '{"status":"confirmada"}' | jq

# Deletar
curl -s -X DELETE http://localhost:3000/reservas/1 -w "%{http_code}"
```

### Encerrar

```bash
docker compose down -v
```

---

## Infraestrutura AWS (Terraform)

### Pré-requisitos
- Terraform >= 1.5
- Credenciais AWS Academy configuradas em `~/.aws/credentials`
- Região: `us-east-1`

### Passo 1 — Criar o backend (S3 + DynamoDB)

```bash
cd infra/backend
terraform init
terraform apply -var="ra=SEU-RA"
```

### Passo 2 — Atualizar o backend em providers.tf

Substitua `technova-tfstate-SEU-RA` pelo nome do bucket criado.

### Passo 3 — Provisionar a infraestrutura

```bash
cd infra
terraform init
terraform plan -var="db_password=SenhaSegura123" -var="repo_url=https://github.com/SEU-USUARIO/prova-primeiro-bimestre-devops"
terraform apply -var="db_password=SenhaSegura123" -var="repo_url=https://github.com/SEU-USUARIO/prova-primeiro-bimestre-devops"
```

### Passo 4 — Acessar a API na nuvem

```bash
# Aguardar ~3 minutos para o user_data concluir
EC2_IP=$(terraform output -raw ec2_public_ip)
curl http://$EC2_IP:3000/health
```

### Passo 5 — Destruir após as evidências

```bash
terraform destroy -var="db_password=SenhaSegura123" -var="repo_url=https://github.com/SEU-USUARIO/prova-primeiro-bimestre-devops"
```

---

## Recursos AWS Provisionados

| Recurso | Tipo | Observação |
|---------|------|------------|
| VPC | `aws_vpc` | CIDR 10.0.0.0/16 |
| Subnets públicas | `aws_subnet` (×2) | 2 AZs |
| Subnets privadas | `aws_subnet` (×2) | 2 AZs, sem NAT |
| Internet Gateway | `aws_internet_gateway` | — |
| Security Group EC2 | `aws_security_group` | Ingress 22, 3000 |
| Security Group RDS | `aws_security_group` | Ingress 5432 só do SG EC2 |
| EC2 | `aws_instance` | t2.micro, AL2023, LabInstanceProfile |
| RDS | `aws_db_instance` | PostgreSQL db.t3.micro, privado, criptografado |
| S3 | `aws_s3_bucket` | Remote state, versionado, AES256 |
| DynamoDB | `aws_dynamodb_table` | Locking do state |

---

## Ferramenta de IA utilizada

**Kiro** (Spec-Driven Development) — geração guiada por spec com requirements → design → tasks.
