# Relatório do Processo — Prova do Primeiro Bimestre (DevOps)

**Aluno:** NOME COMPLETO  
**RA:** SEU-RA  
**Data:** 2026-10-01  
**Ferramenta de IA utilizada:** Kiro (Spec-Driven Development via kiro-cli)

---

## Questão 1 — A Jornada Completa (Aulas 01 a 07)

A construção da API de Reservas da TechNova seguiu a mesma progressão das aulas: cada camada dependia da anterior estar funcionando, o que tornava a ordem natural e necessária.

Comecei pela **Aula 01 (Git)**: criei o repositório no GitHub, configurei o `.gitignore` adequado e estabeleci a convenção de commits. Sem um repositório organizado, qualquer entrega posterior seria frágil — o histórico Git é a documentação viva do que foi feito e quando. Cada etapa concluída gerou um commit com mensagem seguindo o padrão Conventional Commits (`feat:`, `chore:`, `docs:`).

Em seguida, ainda na **Aula 01 (Docker)**, escrevi o `Dockerfile` multi-stage da API. A motivação foi validar a aplicação isolada antes de compô-la com outros serviços. O multi-stage garante imagem final sem devDependencies, e o `USER node` atende ao princípio de menor privilégio — um container não deve rodar como root.

Com a imagem funcionando, avancei para a **Aula 02 (Docker Compose)**: o `docker-compose.yml` compôs a API com o PostgreSQL usando volume nomeado (`pgdata`), rede bridge customizada (`reservas-net`) e healthcheck no banco. A condição `service_healthy` no `depends_on` foi crucial — sem ela, a API subia antes do banco estar pronto e falhava na criação da tabela.

A **Aula 03 (Terraform básico)** entrou com o `infra/backend/main.tf`: o bucket S3 com versionamento e criptografia AES256, mais o DynamoDB para locking. Esse passo precisa acontecer antes do restante do Terraform, pois o remote state é a fundação que permite trabalho colaborativo e recuperação em caso de falha.

As **Aulas 04 e 05 (VPC, EC2, RDS)** foram implementadas como módulos separados: `vpc`, `security-group`, `rds` e `ec2`. A separação em módulos não é burocracia — é o que permite reusar, testar e evoluir cada componente isoladamente. O fluxo de composição no `main.tf` raiz mostrou como o output de um módulo alimenta o input do próximo: VPC gera IDs de subnet → SG usa o VPC ID → RDS usa subnets privadas e SG do RDS → EC2 usa subnet pública, SG da EC2 e endpoint do RDS.

A **Aula 06 (Módulos e Remote State)** foi exatamente esse momento de encaixe: providers.tf com backend `s3`, `variables.tf` com validação de senha, `outputs.tf` expondo IP, endpoint e URL. O remote state garante que o estado Terraform não fique local — qualquer máquina com as credenciais pode continuar o trabalho de onde parou.

A **Aula 07 (IA como copiloto)** atravessou todo o projeto: usei o Kiro para gerar a spec (requirements → design → tasks) antes de qualquer código, o que forçou pensar na arquitetura antes de implementar. A IA acelerou drasticamente a escrita de boilerplate (HCL dos módulos, handlers Express), mas cada arquivo foi revisado para garantir conformidade com as restrições do Learner Lab.

---

## Questão 2 — O Processo com IA como Copiloto

Utilizei o **Kiro** (kiro-cli) com o fluxo Spec-Driven Development: antes de qualquer código, criei uma spec com três documentos — `requirements.md` (user stories e critérios EARS), `design.md` (diagramas de arquitetura e decisões técnicas) e `tasks.md` (lista de tarefas com comandos de validação). Só depois o Kiro gerou os arquivos do projeto.

Os prompts principais foram:
- Um prompt de contexto detalhado descrevendo o projeto, as restrições do Learner Lab (sem IAM, LabInstanceProfile, região us-east-1) e os requisitos técnicos de cada componente
- Especificações explícitas de comportamento da API: quais erros retornar, como tratar `DATE`, como usar `pg.types.setTypeParser`
- Restrições inegociáveis do Terraform: argumentos em linhas separadas, sem engine_version no RDS, `referenced_security_group_id` no SG do RDS (nunca CIDR)

**O que a IA gerou bem:** estrutura completa dos módulos Terraform, handlers assíncronos com tratamento de erro, Dockerfile multi-stage, docker-compose.yml com healthcheck — todos os "esqueletos" que seguem padrões bem estabelecidos e documentados.

**O que precisou ser revisado/corrigido:**
- A IA às vezes tende a usar `security_groups` como argumento direto no `aws_db_instance`, mas no provider ~> 5.0 o correto é `vpc_security_group_ids`. Verificar a documentação foi necessário.
- O healthcheck do Compose com `$${POSTGRES_USER}` (escape duplo no docker-compose.yml) é um detalhe que a IA gera corretamente quando o contexto é detalhado, mas erra em prompts vagos.
- A validação regex da variável `db_password` precisou ser ajustada para funcionar exatamente com o HCL do Terraform 1.5.

**Comparação com fazer manualmente:** escrever todos os módulos Terraform do zero levaria facilmente 3-4 horas. Com o Kiro, o tempo foi de ~30 minutos de revisão e ajustes. A IA economizou tempo especialmente em HCL verboso (blocos de regras de SG, configurações do RDS). Onde atrapalhou foi em detalhes específicos do Learner Lab — a IA não conhece as restrições do ambiente sem que sejam explicitadas no prompt. Prompts vagos geram código que cria IAM roles, o que falha no Lab.

A grande lição: a IA é tão boa quanto o contexto que você fornece. O fluxo Spec → Código (em vez de pedir código diretamente) forçou articular cada decisão antes de implementar, o que resultou em muito menos retrabalho.

---

## Questão 3 — Infraestrutura, Segurança e o Learner Lab

### Arquitetura Provisionada

A infraestrutura segue o padrão clássico de separação pública/privada em duas zonas de disponibilidade:

```
Internet → IGW → Subnet Pública → EC2 (t2.micro)
                                    ↓ porta 5432
                Subnet Privada → RDS PostgreSQL (db.t3.micro)
```

A VPC usa CIDR `10.0.0.0/16`, com subnets públicas nos blocos `.1.0/24` e `.2.0/24` (AZs `us-east-1a` e `us-east-1b`) e subnets privadas nos blocos `.101.0/24` e `.102.0/24`. As subnets privadas não têm NAT Gateway por restrição de custo no Learner Lab.

**Por que RDS na subnet privada e EC2 na pública?**
O banco de dados nunca deve ser acessível diretamente pela internet. Colocá-lo na subnet privada (sem rota pública) garante que, mesmo que o Security Group estivesse mal configurado, não haveria caminho de rede para chegar ao banco de fora da VPC. A EC2 fica na subnet pública porque precisa de IP público para receber requisições HTTP (porta 3000) e para que o `user_data` possa baixar pacotes do DNF e clonar o repositório Git.

**LabRole / LabInstanceProfile:**
O AWS Academy Learner Lab não permite criar `aws_iam_role`, `aws_iam_policy` ou `aws_iam_user`. A role `LabRole` e o instance profile `LabInstanceProfile` já existem no ambiente e fornecem as permissões necessárias para a EC2 (acesso a S3, CloudWatch, etc.). No Terraform, basta referenciar o nome fixo `"LabInstanceProfile"` no argumento `iam_instance_profile` — sem criar nenhum recurso IAM.

**Ajustes específicos do Learner Lab:**
- Credenciais temporárias (AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY + AWS_SESSION_TOKEN) expiram a cada 4 horas. É preciso atualizar `~/.aws/credentials` sempre que o Lab for reiniciado.
- Sem permissão para criar IAM resources — qualquer `aws_iam_*` no Terraform falha com `AccessDenied`.
- Sem NAT Gateway (custo alto para créditos do Lab) — instâncias privadas não têm saída para internet.
- O RDS sem `engine_version` especificado usa a versão padrão da AWS, evitando erros de versão incompatível que ocorrem quando a versão solicitada não está disponível na região.

---

## Questão 4 — Validação e Responsabilidade

### Checklist antes de `terraform apply`

Antes de aplicar qualquer código gerado por IA, executei a seguinte verificação:

1. **`terraform validate`** — verifica sintaxe HCL. É o mínimo inegociável; código que falha aqui não roda.
2. **`terraform plan`** — revisão manual do plano: quais recursos serão criados, modificados ou destruídos. Foco especial em:
   - Ausência de `aws_iam_*` resources (restrição do Lab)
   - `publicly_accessible = false` no RDS
   - `storage_encrypted = true` no RDS
   - `security_groups` do RDS apontando para o SG da EC2 (não CIDR)
   - `iam_instance_profile = "LabInstanceProfile"` na EC2
3. **Grep por segredos hardcoded**: `grep -r "password" infra/ --include="*.tf"` — apenas variáveis, nunca valores.
4. **Verificação do .gitignore**: `git status` antes de qualquer commit para confirmar que `.env`, `.terraform/`, `*.tfstate` e `*.pem` não estão staged.

### O que aconteceria sem revisão

Um exemplo concreto: se eu aceitasse o código de IA sem revisar, era provável que o SG do RDS usasse `cidr_ipv4 = "0.0.0.0/0"` na porta 5432 (um padrão que a IA usa quando o contexto não especifica o contrário). Isso abriria o banco para qualquer IP na internet — exatamente o oposto do objetivo de colocá-lo em subnet privada. A subnet privada provê isolamento de rede, mas um SG mal configurado cria uma brecha na camada de firewall.

Outro risco: código que cria `aws_iam_role` falharia com `AccessDenied` no Learner Lab, desperdiçando tempo e créditos. O checklist de "sem IAM novo" evita isso.

### A evolução Git → Docker → Terraform → Modules e a responsabilidade com IA

Cada aula construiu uma camada de entendimento que é pré-requisito para a próxima:
- **Git** ensinou a registrar cada decisão e reverter erros — um commit granular permite `git revert` cirúrgico.
- **Docker** ensinou que o ambiente deve ser determinístico e reproduzível — um container funciona igual em qualquer máquina, eliminando "funciona na minha máquina".
- **Terraform** aplicou esse princípio à infraestrutura — o estado desejado é declarado em código, auditável e versionado.
- **Módulos** ensinaram separação de responsabilidades: cada módulo tem contrato claro (inputs/outputs) e pode ser testado isoladamente.

Quando a IA gera um módulo Terraform, só consigo avaliar se ele está correto porque entendo o que cada bloco faz. A IA pode gerar `aws_vpc_security_group_ingress_rule` com `referenced_security_group_id` em vez de `cidr_ipv4` — mas só reconheço isso como correto porque a Aula 05 ensinou a diferença entre as duas abordagens e quando usar cada uma.

A responsabilidade com IA não é desconfiar de tudo que ela gera, é saber o suficiente para validar o que importa. O bimestre construiu exatamente esse conhecimento: Git, Docker, Terraform, rede AWS — com cada peça no lugar, o código gerado por IA se torna um ponto de partida que acelera, não um oráculo que substitui o entendimento.
