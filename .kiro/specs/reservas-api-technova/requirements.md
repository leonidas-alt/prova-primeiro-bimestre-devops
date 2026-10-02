# Requirements — reservas-api-technova

## Contexto
API de Reservas da TechNova: CRUD completo sobre o recurso `reservas`, persistido em PostgreSQL,
containerizada com Docker e implantada na AWS com Terraform modularizado.

---

## User Stories e Critérios EARS

### US-01 — Criar Reserva
**Como** cliente da TechNova,  
**quero** criar uma nova reserva informando meu nome e a data desejada,  
**para** garantir meu horário no sistema.

**Critérios de Aceitação (EARS):**
- WHEN o cliente envia POST /reservas com `cliente` e `data` válidos, THEN o sistema SHALL retornar 201 com o objeto criado e `status = "pendente"`.
- WHEN o cliente envia POST /reservas sem `cliente` ou sem `data`, THEN o sistema SHALL retornar 400 com mensagem de erro descritiva.
- WHERE o campo `data` está em formato inválido (não-ISO 8601), THEN o sistema SHALL retornar 400.
- The system SHALL persistir a reserva no PostgreSQL (nunca em memória).
- The system SHALL criar a tabela `reservas` automaticamente no startup se ela não existir.

---

### US-02 — Listar Reservas
**Como** operador da TechNova,  
**quero** listar todas as reservas cadastradas,  
**para** visualizar o calendário de ocupação.

**Critérios de Aceitação (EARS):**
- WHEN o operador envia GET /reservas, THEN o sistema SHALL retornar 200 com array JSON (vazio se não houver registros).
- The system SHALL retornar o campo `data` no formato `"YYYY-MM-DD"` (string).

---

### US-03 — Buscar Reserva por ID
**Como** operador da TechNova,  
**quero** buscar uma reserva específica pelo seu ID,  
**para** consultar os detalhes de um agendamento.

**Critérios de Aceitação (EARS):**
- WHEN o operador envia GET /reservas/:id com ID existente, THEN o sistema SHALL retornar 200 com o objeto da reserva.
- WHEN o operador envia GET /reservas/:id com ID inexistente, THEN o sistema SHALL retornar 404.
- WHEN o operador envia GET /reservas/:id com ID não-numérico, THEN o sistema SHALL retornar 400.

---

### US-04 — Atualizar Reserva
**Como** operador da TechNova,  
**quero** atualizar os dados de uma reserva existente,  
**para** corrigir ou alterar o agendamento.

**Critérios de Aceitação (EARS):**
- WHEN o operador envia PUT /reservas/:id com payload válido e ID existente, THEN o sistema SHALL retornar 200 com o objeto atualizado.
- WHEN o operador envia PUT /reservas/:id com ID inexistente, THEN o sistema SHALL retornar 404.
- WHEN o body contém JSON malformado, THEN o sistema SHALL retornar 400.

---

### US-05 — Excluir Reserva
**Como** operador da TechNova,  
**quero** excluir uma reserva pelo ID,  
**para** liberar o horário no sistema.

**Critérios de Aceitação (EARS):**
- WHEN o operador envia DELETE /reservas/:id com ID existente, THEN o sistema SHALL retornar 204 sem body.
- WHEN o operador envia DELETE /reservas/:id com ID inexistente, THEN o sistema SHALL retornar 404.

---

### US-06 — Health Check
**Como** orquestrador de containers (Docker Compose / AWS),  
**quero** verificar se a API está viva,  
**para** reiniciá-la automaticamente em caso de falha.

**Critérios de Aceitação (EARS):**
- WHEN qualquer cliente envia GET /health, THEN o sistema SHALL retornar 200 com `{"status": "ok"}`.
- The system SHALL responder ao health check mesmo quando o banco estiver temporariamente indisponível (retorna degraded, não crash).

---

### US-07 — Ambiente Local (Docker Compose)
**Como** desenvolvedor,  
**quero** subir a API + PostgreSQL com um único comando,  
**para** desenvolver e testar localmente.

**Critérios de Aceitação (EARS):**
- WHEN o desenvolvedor executa `docker compose up -d`, THEN o sistema SHALL iniciar os serviços `db` e `api` sem erros.
- The system SHALL usar volume nomeado `pgdata` para persistir os dados do banco.
- The system SHALL aguardar o banco estar saudável (`pg_isready`) antes de iniciar a API.
- The system SHALL ler configurações de um arquivo `.env` (nunca hardcoded).

---

### US-08 — Infraestrutura AWS (Terraform)
**Como** engenheiro de infraestrutura,  
**quero** provisionar VPC, SG, EC2 e RDS com Terraform modularizado,  
**para** ter um ambiente reproduzível e versionado na AWS.

**Critérios de Aceitação (EARS):**
- The system SHALL usar remote state (S3 + DynamoDB) para o estado do Terraform.
- The system SHALL provisionar RDS nas subnets privadas com `publicly_accessible = false` e `storage_encrypted = true`.
- The system SHALL restringir a porta 5432 ao Security Group da EC2 (nunca via CIDR público).
- The system SHALL usar `LabInstanceProfile` na EC2, sem criar IAM users/roles/policies.
- The system SHALL provisionar toda a infra na região `us-east-1`.
- The system SHALL aplicar tags (`Project`, `Owner`, `Env`) em todos os recursos.
- WHEN `terraform validate` é executado, THEN o sistema SHALL retornar sem erros de sintaxe.

---

## Restrições Não-Funcionais

| Restrição | Valor |
|-----------|-------|
| Runtime | Node.js 20 |
| Banco de dados | PostgreSQL (pg driver, queries parametrizadas) |
| Container | Docker multi-stage, usuário não-root (`node`) |
| Terraform | >= 1.5, provider AWS ~> 5.0 |
| Região AWS | us-east-1 |
| IAM | Somente `LabInstanceProfile` (sem criar novos recursos IAM) |
| Segredos | Nunca hardcoded em arquivos versionados |
