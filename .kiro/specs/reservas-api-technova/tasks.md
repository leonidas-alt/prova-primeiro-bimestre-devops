# Tasks — reservas-api-technova

Cada tarefa inclui: **arquivos criados**, **comando de validação** e **mensagem de commit sugerida**.

---

## T-01 — Estrutura base e .gitignore

**Arquivos:**
- `.gitignore`

**Comando de validação:**
```bash
cat .gitignore | grep -E "node_modules|\.env|\.terraform|tfstate|\.pem"
# Deve exibir todas as entradas
```

**Commit:**
```
chore: add .gitignore para node, docker e terraform
```

---

## T-02 — Aplicação Node.js

**Arquivos:**
- `app/package.json`
- `app/src/index.js`
- `app/src/db.js`
- `app/src/routes/reservas.js`

**Comandos de validação:**
```bash
# Instalar deps e checar sintaxe
cd app && npm install && node --check src/index.js

# Teste rápido com banco local (requer .env preenchido)
# node src/index.js &
# curl -s http://localhost:3000/health
# curl -s -X POST http://localhost:3000/reservas \
#   -H "Content-Type: application/json" \
#   -d '{"cliente":"Ana","data":"2026-11-01"}' | jq
```

**Commit:**
```
feat: add API de reservas Node.js com CRUD e persistência PostgreSQL
```

---

## T-03 — Dockerfile e .dockerignore

**Arquivos:**
- `app/Dockerfile`
- `app/.dockerignore`

**Comandos de validação:**
```bash
cd app
docker build -t reservas-api:local .
docker inspect reservas-api:local | jq '.[0].Config.User'
# Deve retornar "node"
docker image ls reservas-api:local
```

**Commit:**
```
feat: add Dockerfile multi-stage com USER node
```

---

## T-04 — Docker Compose e .env.example

**Arquivos:**
- `docker-compose.yml`
- `.env.example`

**Comandos de validação:**
```bash
# Copiar .env e preencher senha
cp .env.example .env
# Edite .env com POSTGRES_PASSWORD=<senha>

docker compose config          # valida sintaxe
docker compose up -d
docker compose ps              # api e db devem estar "healthy" / "running"
curl -s http://localhost:3000/health
# {"status":"ok"}

curl -s -X POST http://localhost:3000/reservas \
  -H "Content-Type: application/json" \
  -d '{"cliente":"Maria","data":"2026-12-01"}' | jq
```

**Commit:**
```
feat: add docker-compose.yml com PostgreSQL, healthcheck e rede customizada
```

---

## T-05 — Backend Terraform (S3 + DynamoDB)

**Arquivos:**
- `infra/backend/main.tf`

**Comandos de validação:**
```bash
cd infra/backend
terraform init
terraform validate
terraform plan
# terraform apply -auto-approve   # executar manualmente
```

**Commit:**
```
chore: add terraform backend com S3 e DynamoDB para remote state
```

---

## T-06 — Raiz Terraform (providers, variables, outputs, main)

**Arquivos:**
- `infra/providers.tf`
- `infra/variables.tf`
- `infra/outputs.tf`
- `infra/main.tf`

**Comandos de validação:**
```bash
cd infra
terraform init
terraform validate
# Deve retornar: "Success! The configuration is valid."
```

**Commit:**
```
feat: add terraform root com providers, variables, outputs e composição de módulos
```

---

## T-07 — Módulo vpc

**Arquivos:**
- `infra/modules/vpc/main.tf`
- `infra/modules/vpc/variables.tf`
- `infra/modules/vpc/outputs.tf`

**Comandos de validação:**
```bash
cd infra
terraform validate
terraform plan -target=module.vpc
```

**Commit:**
```
feat: add módulo terraform vpc com subnets públicas e privadas em 2 AZs
```

---

## T-08 — Módulo security-group

**Arquivos:**
- `infra/modules/security-group/main.tf`
- `infra/modules/security-group/variables.tf`
- `infra/modules/security-group/outputs.tf`

**Comandos de validação:**
```bash
cd infra
terraform validate
terraform plan -target=module.security_group
```

**Commit:**
```
feat: add módulo terraform security-group com regras mínimas EC2 e RDS
```

---

## T-09 — Módulo rds

**Arquivos:**
- `infra/modules/rds/main.tf`
- `infra/modules/rds/variables.tf`
- `infra/modules/rds/outputs.tf`

**Comandos de validação:**
```bash
cd infra
terraform validate
terraform plan -target=module.rds
# Verificar: publicly_accessible = false, storage_encrypted = true
```

**Commit:**
```
feat: add módulo terraform rds PostgreSQL privado e criptografado
```

---

## T-10 — Módulo ec2

**Arquivos:**
- `infra/modules/ec2/main.tf`
- `infra/modules/ec2/variables.tf`
- `infra/modules/ec2/outputs.tf`

**Comandos de validação:**
```bash
cd infra
terraform validate
terraform plan -target=module.ec2
# Verificar: iam_instance_profile = "LabInstanceProfile"
```

**Commit:**
```
feat: add módulo terraform ec2 com user_data para deploy da API
```

---

## T-11 — README.md e evidencias/

**Arquivos:**
- `README.md`
- `evidencias/README.md`

**Comandos de validação:**
```bash
cat README.md | grep -E "Nome|RA|Descrição"
ls evidencias/
```

**Commit:**
```
docs: add README.md e estrutura de evidências
```

---

## T-12 — relatorio.md

**Arquivos:**
- `relatorio.md`

**Comandos de validação:**
```bash
grep -E "Questão [1-4]" relatorio.md
wc -l relatorio.md   # deve ter conteúdo substancial
```

**Commit:**
```
docs: add relatorio.md com as 4 questões dissertativas
```

---

## T-13 — Terraform plan completo (pré-apply)

**Prerequisito:** backend aplicado, credenciais AWS configuradas.

**Comandos de validação:**
```bash
cd infra
export TF_VAR_db_password="SenhaSegura123"
terraform plan -out=tfplan.bin
terraform show tfplan.bin | grep -E "will be created|Plan:"
# Salvar saída em evidencias/terraform-plan.txt
terraform show tfplan.bin > ../evidencias/terraform-plan.txt
```

**Commit:**
```
chore: add evidencia terraform plan
```

---

## T-14 — Apply e evidências finais

**Comandos de validação:**
```bash
cd infra
terraform apply tfplan.bin

# Capturar outputs
terraform output
EC2_IP=$(terraform output -raw ec2_public_ip)

# Aguardar ~3 minutos para user_data finalizar
curl -s http://$EC2_IP:3000/health

# Salvar evidências
docker compose ps > evidencias/compose-ps.txt
docker build --no-cache -t reservas-api:local ./app 2>&1 > evidencias/docker-build.txt

# APÓS capturar tudo:
terraform destroy -auto-approve
```

**Commit:**
```
chore: add evidencias finais do ambiente AWS
```

---

## Checklist Final (Auto-revisão)

| Item | Verificação |
|------|-------------|
| `terraform validate` sem erros | `cd infra && terraform validate` |
| RDS privado | `publicly_accessible = false` em `infra/modules/rds/main.tf` |
| RDS criptografado | `storage_encrypted = true` em `infra/modules/rds/main.tf` |
| Porta 5432 só pelo SG | `security_groups` no SG RDS, sem CIDR |
| Sem IAM novo | `grep -r "aws_iam" infra/` → apenas referências, sem resource |
| Região us-east-1 | `grep region infra/providers.tf` |
| Tags em todos os recursos | `grep -r "tags" infra/modules/` |
| Sem segredos hardcoded | `grep -r "password" infra/ --include="*.tf"` → apenas variáveis |
| Dockerfile USER node | `grep "USER node" app/Dockerfile` |
| `.env` no .gitignore | `git check-ignore -v .env` |
