# oficina-infra-k8s

## Visão geral

Repositório que provisiona a camada Kubernetes e a entrada pública da solução Oficina. Contém quatro roots Terraform independentes: cluster EKS e ECR, controlador opcional de Load Balancer, HTTP API com VPC Link e observabilidade New Relic.

## Tecnologias utilizadas

- Terraform
- AWS EKS, ECR e Network Load Balancer
- AWS API Gateway HTTP API e VPC Link
- AWS SSM Parameter Store
- Helm (somente no modo `aws_lbc`)
- New Relic (opcional)
- GitHub Actions

## Solução integrada

A solução Oficina é composta por 4 repositórios independentes que, juntos, formam um sistema de gestão de oficina mecânica na AWS.

```mermaid
graph LR
  DB[oficina-infra-db<br/>VPC + RDS] --> K8S_CORE[oficina-infra-k8s core<br/>EKS + ECR + NLB]
  DB --> LMB[oficina-auth-lambda<br/>auth-cpf + jwt-authorizer]
  K8S_CORE --> API[oficina-api<br/>.NET 10 no EKS]
  K8S_CORE --> APIGW[oficina-infra-k8s api-gateway<br/>HTTP API + VPC Link]
  LMB --> APIGW
  API --> APIGW
```

| Passo | Repositório | Workflow | Quando aplicar |
|---|---|---|---|
| 1 | `oficina-infra-db` | Terraform Apply | sempre |
| 2 | `oficina-infra-k8s` root `terraform` (core) | Terraform Apply | sempre |
| 2a | `oficina-infra-k8s` root `terraform/addons` | Terraform Apply | apenas se `LOAD_BALANCER_PROVISIONING_MODE=aws_lbc` |
| 3 | `oficina-api` | Deploy API | sempre |
| 4 | `oficina-auth-lambda` | Deploy Lambda | sempre |
| 5 | `oficina-infra-k8s` root `terraform/api-gateway` | Terraform API Gateway Apply | sempre |
| 6 | `oficina-api` | Deploy API (redeploy) | se o pod precisar refletir `public-base-url` recém-criado em e-mails |

Cada README detalha apenas a responsabilidade do seu repositório. Para o passo a passo dos demais, consulte os READMEs correspondentes.

## Responsabilidade deste repositório

- Provisiona EKS, Node Group, ECR e o NLB interno (modo padrão).
- Provisiona o API Gateway HTTP, VPC Link e rotas que integram a API e as Lambdas.
- Publica parâmetros SSM consumidos pelos demais repositórios.
- Não constrói imagens, não cria roles IAM de EKS (pré-requisito manual) nem provisiona RDS, VPC ou Lambdas.

## Arquitetura

```mermaid
graph TB
  subgraph CORE[root core]
    EKS[EKS Cluster]
    ECR[ECR Repository]
    NLB[NLB interno]
    SSM1[(SSM backend-listener-arn)]
  end
  subgraph ADDONS[root addons - opcional]
    LBC[AWS Load Balancer Controller]
  end
  subgraph APIGW[root api-gateway]
    HTTP[HTTP API + VPC Link]
    SSM2[(SSM public-base-url)]
  end
  subgraph OBS[root observability - opcional]
    NR[New Relic]
  end
  CORE -. modo terraform_nlb .-> SSM1
  ADDONS -. modo aws_lbc .-> LBC
  LBC --> NLB
  APIGW --> SSM1
  APIGW --> SSM2
  OBS -.-> EKS
```

## Estrutura de roots Terraform

| Root | Propósito | Quando aplicar |
| --- | --- | --- |
| `terraform/` (core) | EKS, Node Group, ECR e NLB interno (modo `terraform_nlb`) | sempre |
| `terraform/addons/` | AWS Load Balancer Controller via Helm | apenas no modo `aws_lbc` |
| `terraform/api-gateway/` | HTTP API, VPC Link, rotas e integrações | sempre, após `oficina-api` e `oficina-auth-lambda` |
| `terraform/observability/` | New Relic (dashboards, alertas, Synthetic Monitor) | opcional |

Cada root tem `backend.tf` próprio e state isolado em `s3://<bucket-de-state>/oficina-infra-k8s/<ambiente>/{core|addons|api-gateway|observability}/terraform.tfstate`.

## Pré-requisitos manuais (IAM Roles do EKS)

As roles IAM do EKS **devem pré-existir** antes do deploy — o workflow não as cria. São necessárias duas roles distintas:

**Role do control plane** (`TF_VAR_eks_cluster_role_arn`)

- Trust policy: `eks.amazonaws.com`
- Política gerenciada: `AmazonEKSClusterPolicy`

**Role dos nodes** (`TF_VAR_eks_node_role_arn`)

- Trust policy: `ec2.amazonaws.com`
- Políticas gerenciadas:
  - `AmazonEKSWorkerNodePolicy`
  - `AmazonEKS_CNI_Policy`
  - `AmazonEC2ContainerRegistryReadOnly`

Para listar as roles disponíveis na conta e obter os ARNs:

```powershell
$env:AWS_REGION="<regiao>"

aws iam list-roles --query "Roles[?contains(RoleName,'eks')].{Nome:RoleName,ARN:Arn}" --output table
aws iam get-role --role-name "<nome-da-role>" --query "Role.Arn" --output text
```

## Modos de provisionamento do Load Balancer

A variável `LOAD_BALANCER_PROVISIONING_MODE` define como o NLB é criado:

| Modo | Quem cria o NLB | Quem grava `backend-listener-arn` no SSM | Precisa rodar `addons`? |
| --- | --- | --- | --- |
| `terraform_nlb` (padrão) | Terraform deste repositório (root `core`) | Terraform deste repositório (root `core`) | não |
| `aws_lbc` | AWS Load Balancer Controller (via Kubernetes Service) | Workflow do `oficina-api` após o Service subir | sim |

No modo `aws_lbc`, a variável `TF_VAR_aws_load_balancer_controller_iam_mode` define `node` (padrão, herda da node IAM role) ou `irsa` (role dedicada com OIDC; recomendado).

## Valores consumidos

| Origem | Valor | Como é consumido |
| --- | --- | --- |
| `oficina-infra-db` | `vpc_id`, `vpc_cidr_block`, `public_subnet_ids`, `private_subnet_ids` | `data.terraform_remote_state.db` no S3 |
| `oficina-auth-lambda` | funções `oficina-auth-cpf` e `oficina-jwt-authorizer` | `data "aws_lambda_function"` durante o apply do root `api-gateway` (as Lambdas já precisam existir) |

## Valores gerados

| Recurso | Consumido por | Como é consumido |
| --- | --- | --- |
| `ECR Repository` | `oficina-api` | push de imagem via `aws ecr` |
| `EKS Cluster Name` | `oficina-api` | `aws eks update-kubeconfig` |
| `SSM /<projeto>/<ambiente>/api/backend-listener-arn` | root `api-gateway` deste repositório | data source no Terraform |
| `SSM /<projeto>/<ambiente>/api/public-base-url` | `oficina-api` | lido pelo workflow `deploy-api` para compor links em e-mails |
| `API Gateway URL` | consumo externo (clientes da solução) | URL pública do HTTP API |

## Configuração necessária

Configure no GitHub Actions:

| Nome | Tipo | Obrigatório | Origem ou Default | Descrição |
| --- | --- | --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | Secret | Sim | — | Credencial AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Sim | — | Credencial AWS |
| `AWS_SESSION_TOKEN` | Secret | Não | — | Credenciais temporárias (STS) |
| `AWS_REGION` | Secret | Sim | — | Região AWS |
| `TF_STATE_BUCKET` | Secret | Sim | Auto-provisionado pelo workflow | Bucket S3 do state; criado se não existir |
| `TF_VAR_eks_cluster_role_arn` | Secret | Sim | Criada manualmente (ver pré-requisitos) | ARN da role do control plane EKS |
| `TF_VAR_eks_node_role_arn` | Secret | Sim | Criada manualmente (ver pré-requisitos) | ARN da role do node group |
| `PROJECT_NAME` | Variable | Não | `oficina` | Prefixo lógico |
| `ENVIRONMENT` | Variable | Não | `dev` | Ambiente |
| `EKS_CLUSTER_NAME` | Variable | Não | `oficina-eks` | Nome do cluster |
| `ECR_REPOSITORY_NAME` | Variable | Não | `oficina-api` | Nome do repositório ECR |
| `LOAD_BALANCER_PROVISIONING_MODE` | Variable | Não | `terraform_nlb` | `terraform_nlb` ou `aws_lbc` |
| `API_NODE_PORT` | Variable | Não | `30080` | NodePort da API (faixa 30000-32767) |
| `TF_VAR_aws_load_balancer_controller_iam_mode` | Variable | Não | `node` | `node` ou `irsa`; usado apenas no modo `aws_lbc` |
| `AUTH_FUNCTION_NAME` | Variable | Não | `oficina-auth-cpf` | Nome da Lambda de autenticação (consumida pelo `api-gateway`) |
| `AUTHORIZER_FUNCTION_NAME` | Variable | Não | `oficina-jwt-authorizer` | Nome da Lambda authorizer |

A regra de Security Group do NodePort restringe a faixa `30000-32767` ao CIDR da VPC. Não altere para `0.0.0.0/0`.

## Como executar

### Root core (passo 2)

Pull requests executam `Terraform Check` com `fmt`, `init -backend=false` e `validate`.

Após o merge na `main`, execute manualmente:

```text
GitHub Actions > Terraform Apply > Run workflow
```

No modo `terraform_nlb`, o job de addons é ignorado. O Target Group permanece sem targets saudáveis até o deploy do `oficina-api`; isso é esperado.

No modo `aws_lbc`, o mesmo workflow também aplica os addons (AWS Load Balancer Controller via Helm).

### Root api-gateway (passo 5)

Após o deploy da API e das Lambdas, execute:

```text
GitHub Actions > Terraform API Gateway Apply > Run workflow
```

### Root observability (opcional)

Pull requests e push na `main` executam apenas `validate` e `plan`. O `apply` exige `workflow_dispatch` com o input `apply=true`.

## Como validar pela AWS

### Console — após o root core

- Em EKS, confirme cluster e node group ativos.
- Em ECR, confirme o repositório da API.
- Em EC2 > Load Balancers (modo `terraform_nlb`), confirme o NLB interno.
- Em SSM Parameter Store (modo `terraform_nlb`), confirme `/${PROJECT_NAME}/${ENVIRONMENT}/api/backend-listener-arn`.
- Em Security Groups, confirme NodePort restrito ao CIDR da VPC.

### Console — após o root api-gateway

- Em API Gateway, confirme HTTP API, VPC Link e rotas (`POST /api/auth/cpf`, `GET /health`, `ANY /api/{proxy+}`).
- Em SSM Parameter Store, confirme `/${PROJECT_NAME}/${ENVIRONMENT}/api/public-base-url`.

### CLI (PowerShell) — após o root core

```powershell
$env:AWS_REGION="<regiao>"
$env:ENVIRONMENT="<ambiente>"
$env:PROJECT_NAME="oficina"
$env:EKS_CLUSTER_NAME="<nome-do-cluster>"
$env:ECR_REPOSITORY_NAME="<nome-do-repositorio-ecr>"

aws eks describe-cluster --name $env:EKS_CLUSTER_NAME --region $env:AWS_REGION --query "cluster.status"
aws eks describe-nodegroup --cluster-name $env:EKS_CLUSTER_NAME --nodegroup-name "$($env:PROJECT_NAME)-node-group" --region $env:AWS_REGION --query "nodegroup.status"
aws ecr describe-repositories --repository-names $env:ECR_REPOSITORY_NAME --region $env:AWS_REGION --query "length(repositories)"
aws ssm get-parameter --name "/$($env:PROJECT_NAME)/$($env:ENVIRONMENT)/api/backend-listener-arn" --region $env:AWS_REGION --query "Parameter.Name"
```

### CLI (PowerShell) — após o root api-gateway

```powershell
aws apigatewayv2 get-apis --region $env:AWS_REGION --query "Items[?contains(Name,'$($env:PROJECT_NAME)')].{Nome:Name,Protocolo:ProtocolType}"
aws ssm get-parameter --name "/$($env:PROJECT_NAME)/$($env:ENVIRONMENT)/api/public-base-url" --region $env:AWS_REGION --query "Parameter.Name"
```

## Como executar localmente

Apenas validações não destrutivas em cada root:

```powershell
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate

terraform -chdir=terraform/addons fmt -check -recursive
terraform -chdir=terraform/addons init -backend=false
terraform -chdir=terraform/addons validate

terraform -chdir=terraform/api-gateway fmt -check -recursive
terraform -chdir=terraform/api-gateway init -backend=false
terraform -chdir=terraform/api-gateway validate

terraform -chdir=terraform/observability fmt -check -recursive
terraform -chdir=terraform/observability init -backend=false
terraform -chdir=terraform/observability validate
```

## Monitoramento e Observabilidade

O root `terraform/observability` provisiona dashboards, alertas, workflow de notificação e Synthetic Monitor no New Relic. O padrão é seguro: `enable_new_relic=false` permite `validate` sem credenciais.

### Configurar

| Nome | Tipo | Obrigatório quando habilitado | Origem ou Default | Descrição |
| --- | --- | --- | --- | --- |
| `NEW_RELIC_LICENSE_KEY` | Secret | Sim | — | License key usada pela Kubernetes integration |
| `NEW_RELIC_USER_API_KEY` | Secret | Sim | — | User API key usada pelo provider Terraform New Relic |
| `NEW_RELIC_ACCOUNT_ID` | Secret | Sim | — | Account ID New Relic usado por dashboards e alertas |
| `NEW_RELIC_NOTIFICATION_EMAIL` | Secret | Sim | — | E-mail destino das notificações |
| `NEW_RELIC_REGION` | Variable | Não | `US` | `US` ou `EU` |
| `API_GATEWAY_URL` | Secret ou Variable | Não | vazio (desabilita Synthetic) | URL pública usada pelo Synthetic Monitor |

A variável Terraform `enable_new_relic` deve ser `true` para criar recursos no New Relic. Para que APM, traces e logs do `oficina-api` cheguem ao New Relic, o pod precisa receber as variáveis `OTEL_EXPORTER_OTLP_*` (configurado pelo workflow `deploy-api` do repositório `oficina-api`).

### Executar

```text
GitHub Actions > Terraform Observability > Run workflow > apply = true
```

Quando aplicado, o workflow instala o chart `nri-bundle` no namespace `newrelic`, cria dashboards, condições de alerta, workflow de notificação e Synthetic Monitor. Os valores sensíveis (license key, user API key, account id, ARNs, IDs, URLs internas, YAML completo) são mascarados pelo workflow.

### Validar

Console New Relic:

- **APM**: confirme entidade `oficina-api` com transações em `/api/*` e `/health`.
- **Logs**: filtre por `correlationId` e `eventType` (`OrdemServicoCriada`, `OrdemServicoStatusAlterado`, `OrdemServicoFalha`, `EmailOrcamentoFalha`).
- **Kubernetes**: confirme cluster, nodes, pods e logs dos pods sob a integração `nri-bundle`.
- **Dashboards**: latência da API, erros 5xx, uptime, CPU e memória Kubernetes, volume diário de OS, tempo médio por status, falhas de OS.
- **Alertas**: force uma condição controlada ou reduza thresholds temporariamente em ambiente não produtivo e confirme a abertura da issue.
- **Synthetic**: quando `API_GATEWAY_URL` estiver configurada, confirme o monitor de `/health` validando a string `Healthy`.

CLI (PowerShell) — componentes Kubernetes do `nri-bundle`:

```powershell
$env:AWS_REGION="<regiao>"
$env:EKS_CLUSTER_NAME="<nome-do-cluster>"

aws eks update-kubeconfig --name $env:EKS_CLUSTER_NAME --region $env:AWS_REGION
kubectl get pods -n newrelic
kubectl get daemonset -n newrelic
```

## Próxima etapa

No modo `terraform_nlb`, executar `oficina-api`. No modo `aws_lbc`, executar o root `terraform/addons` antes da API. Em seguida, publicar `oficina-auth-lambda` e voltar a este repositório para aplicar o root `terraform/api-gateway`.
