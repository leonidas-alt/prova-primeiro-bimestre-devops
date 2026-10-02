# Design — reservas-api-technova

## 1. Visão Geral

A solução entrega a API de Reservas da TechNova em dois ambientes:
- **Local**: Docker Compose (api + db)
- **Nuvem**: AWS via Terraform modularizado (EC2 + RDS + VPC + SG)

---

## 2. Arquitetura da Aplicação (Node.js)

```
app/
├── src/
│   ├── index.js          # bootstrap: cria tabela, registra rotas, middleware de erro
│   ├── db.js             # pool pg, pg.types.setTypeParser(1082), ssl condicional
│   └── routes/
│       └── reservas.js   # handlers CRUD + /health
├── package.json          # deps: express, pg; script start
├── Dockerfile            # multi-stage, USER node, EXPOSE 3000
└── .dockerignore
```

### Fluxo de requisição
```
Cliente HTTP
    │
    ▼
Express Router (/reservas, /health)
    │
    ▼
Async Handler (try/catch)
    │
    ├─► Pool pg → PostgreSQL (queries parametrizadas)
    │
    └─► Error Middleware
            ├── 22P02 / 22007 / 22008 / SyntaxError → 400
            └── demais → 500
```

### Schema da tabela
```sql
CREATE TABLE IF NOT EXISTS reservas (
  id      SERIAL PRIMARY KEY,
  cliente TEXT NOT NULL,
  data    DATE NOT NULL,
  status  TEXT NOT NULL DEFAULT 'pendente'
);
```

### Variáveis de ambiente
| Variável | Descrição | Default |
|----------|-----------|---------|
| DB_HOST | Host do PostgreSQL | — |
| DB_PORT | Porta do PostgreSQL | 5432 |
| POSTGRES_USER | Usuário do banco | — |
| POSTGRES_PASSWORD | Senha do banco | — |
| POSTGRES_DB | Nome do banco | — |
| PORT | Porta da API | 3000 |
| DB_SSL | Ativa SSL (RDS) | false |

---

## 3. Ambiente Local — Docker Compose

```
┌─────────────────────────────────────────┐
│            reservas-net (bridge)        │
│                                         │
│  ┌──────────────┐    ┌───────────────┐  │
│  │   api        │    │     db        │  │
│  │ (Node.js 20) │───►│ (postgres:16) │  │
│  │ porta 3000   │    │ porta 5432    │  │
│  └──────────────┘    └──────┬────────┘  │
│         ▲                   │           │
│    depends_on          volume pgdata    │
│    (service_healthy)                    │
└─────────────────────────────────────────┘
         │
    HOST:3000
```

- Healthcheck no `db`: `pg_isready -U $POSTGRES_USER -d $POSTGRES_DB`
- `api` inicia somente após `db: condition: service_healthy`
- `.env` nunca versionado; `.env.example` documenta as variáveis

---

## 4. Infraestrutura AWS — Terraform

### Diagrama de Rede

```
us-east-1
┌────────────────────────────────────────────────────────┐
│  VPC 10.0.0.0/16                                       │
│                                                        │
│  ┌─────────────────────┐  ┌─────────────────────────┐  │
│  │  AZ us-east-1a      │  │  AZ us-east-1b          │  │
│  │                     │  │                         │  │
│  │  subnet pública     │  │  subnet pública         │  │
│  │  10.0.1.0/24        │  │  10.0.2.0/24            │  │
│  │  ┌───────────────┐  │  │                         │  │
│  │  │  EC2 t2.micro │  │  │                         │  │
│  │  │  SG-EC2       │  │  │                         │  │
│  │  │  22, 3000     │  │  │                         │  │
│  │  └───────────────┘  │  │                         │  │
│  │                     │  │                         │  │
│  │  subnet privada     │  │  subnet privada         │  │
│  │  10.0.101.0/24      │  │  10.0.102.0/24          │  │
│  │  ┌───────────────┐  │  │  ┌─────────────────┐   │  │
│  │  │  RDS Primary  │  │  │  │  RDS Standby    │   │  │
│  │  │  db.t3.micro  │  │  │  │  (subnet group) │   │  │
│  │  │  SG-RDS       │  │  │  └─────────────────┘   │  │
│  │  │  5432 ← SG-EC2│  │  │                         │  │
│  │  └───────────────┘  │  │                         │  │
│  └─────────────────────┘  └─────────────────────────┘  │
│                                                        │
│  Internet Gateway ──► Route Table Pública              │
│  Route Table Privada (sem NAT)                         │
└────────────────────────────────────────────────────────┘
```

### Módulos Terraform

| Módulo | Responsabilidade | Inputs principais | Outputs |
|--------|-----------------|-------------------|---------|
| `vpc` | VPC, subnets, IGW, route tables | `project`, `env`, `cidr_block` | `vpc_id`, `public_subnet_ids`, `private_subnet_ids` |
| `security-group` | SG EC2 e SG RDS | `vpc_id`, `allowed_cidr` | `ec2_sg_id`, `rds_sg_id` |
| `rds` | RDS PostgreSQL | `private_subnet_ids`, `rds_sg_id`, `db_*` | `rds_endpoint` |
| `ec2` | EC2 + user_data | `public_subnet_ids[0]`, `ec2_sg_id`, `rds_endpoint`, `db_*`, `repo_*` | `public_ip` |

### Composição (infra/main.tf)
```
module vpc → module security-group → module rds
                                   ↘ module ec2
```

### Remote State
```
infra/backend/main.tf
  └─► S3 bucket: technova-tfstate-<RA>  (versionamento + AES256 + block public access)
  └─► DynamoDB: technova-tf-lock        (PAY_PER_REQUEST, hash_key LockID)

infra/providers.tf
  └─► backend "s3" aponta para os recursos acima
```

### user_data da EC2 (resumo)
1. `dnf install -y docker git`
2. `systemctl enable --now docker`
3. `git clone <repo_url> -b <repo_branch> /opt/app`
4. `docker build -t reservas-api /opt/app/app`
5. `docker run -d --restart unless-stopped -p 3000:3000 -e DB_HOST=... reservas-api`
6. Log em `/var/log/user-data.log`

---

## 5. Fluxo de Deploy

```
1. git init + commits convencionais
2. docker compose up -d   (valida local)
3. cd infra/backend && terraform init && terraform apply   (cria S3 + DynamoDB)
4. cd infra && terraform init && terraform plan
5. terraform apply         (provisiona VPC → SG → RDS → EC2)
6. curl http://<EC2_IP>:3000/health
7. terraform destroy       (após capturar evidências)
```

---

## 6. Decisões de Design

| Decisão | Justificativa |
|---------|---------------|
| pg com queries parametrizadas | Previne SQL injection |
| `pg.types.setTypeParser(1082)` | Retorna DATE como string `YYYY-MM-DD` sem conversão de timezone |
| Multi-stage Dockerfile | Imagem final menor, sem devDependencies |
| `USER node` no Dockerfile | Princípio de menor privilégio |
| RDS em subnet privada | Nunca exposto à internet |
| SG RDS com `security_groups` | Acesso apenas da EC2, sem CIDR público |
| `LabInstanceProfile` fixo | Restrição do AWS Academy Learner Lab |
| `skip_final_snapshot = true` | Facilita destroy no Lab sem erro |
| `backup_retention_period = 0` | Sem custo de backup no Lab |
| Sem `engine_version` no RDS | AWS usa a versão padrão, evita conflito de versão no Lab |
