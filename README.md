# oficina-infra-k8s

## Visão geral

Este repositório provisiona a camada Kubernetes e a entrada pública da solução Oficina. Ele contém três roots Terraform:

- `terraform`: EKS, ECR e, no modo padrão, NLB interno da API.
- `terraform/addons`: instalação opcional do AWS Load Balancer Controller.
- `terraform/api-gateway`: HTTP API, VPC Link, rotas e integrações com backend e Lambdas.

O modo padrão é `terraform_nlb`: o Terraform cria o NLB interno, Target Group, Listener e parâmetro SSM do Listener ARN. O modo `aws_lbc` é uma opção avançada quando a conta tem permissões para usar o AWS Load Balancer Controller.

## Diagrama de arquitetura

```text
                    ┌──────────────────────────────────────┐
                    │         API Gateway HTTP API         │
                    │  única entrada pública da solução    │
                    └────────────┬─────────────────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          │                      │                      │
  POST /api/auth/cpf    GET /health              ANY /api/{proxy+}
          │              sem auth                JWT Authorizer
          ▼                      │                      │
  Lambda Auth CPF                │              Lambda Authorizer
  VPC + RDS                      │              sem VPC
  gera JWT                       │                      │
                                 └──────────┬───────────┘
                                            │
                                      VPC Link privado
                                            │
                                   NLB interno privado
                                   subnets privadas
                                            │
                               EKS Node Group público
                               NodePort :30080
                                            │
                                   oficina-api Pods
                                            │
                                   RDS SQL Server
                                   subnets privadas
```

## Tecnologias utilizadas

- Terraform
- AWS EKS e ECR
- AWS Network Load Balancer
- AWS API Gateway HTTP API e VPC Link
- AWS SSM Parameter Store
- Helm, somente no modo `aws_lbc`
- GitHub Actions

## Sequência de Deploy (modo padrão `terraform_nlb`)

| Passo | Repositório | O que provisiona |
|-------|-------------|-----------------|
| 1 | oficina-infra-db | VPC, subnets, RDS SQL Server |
| **2** | **oficina-infra-k8s core ← este** | EKS, ECR, NLB interno |
| 3 | oficina-api | Migrations, Deployment, Service |
| 4 | oficina-auth-lambda | Lambdas de autenticação |
| **5** | **oficina-infra-k8s API Gateway ← este** | Entrada pública (HTTP API) |
| 6 | oficina-api (opcional) | Redeploy para URL pública em e-mails |

No modo `aws_lbc`, inserir `oficina-infra-k8s addons` entre os passos 2 e 3.

## Pré-requisitos de IAM

As roles IAM do EKS **devem pré-existir** antes do deploy. O workflow não as cria. São necessárias duas roles:

**Role do control plane** (`TF_VAR_eks_cluster_role_arn`)
- Trust policy: `eks.amazonaws.com`
- Política gerenciada: `arn:aws:iam::aws:policy/AmazonEKSClusterPolicy`

**Role dos nodes** (`TF_VAR_eks_node_role_arn`)
- Trust policy: `ec2.amazonaws.com`
- Políticas gerenciadas:
  - `arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy`
  - `arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy`
  - `arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly`

Para listar as roles disponíveis na conta e obter os ARNs:

```powershell
$env:AWS_REGION="<regiao>"

# Listar roles com nome contendo "eks"
aws iam list-roles --query "Roles[?contains(RoleName,'eks')].{Nome:RoleName,ARN:Arn}" --output table

# Obter ARN de uma role específica pelo nome
aws iam get-role --role-name "<nome-da-role>" --query "Role.Arn" --output text
```

## Configuração necessária

Configure no GitHub Actions:

| Nome | Tipo | Uso |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | Secret | Autenticação AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Autenticação AWS |
| `AWS_SESSION_TOKEN` | Secret opcional | Credenciais temporárias |
| `AWS_REGION` | Secret | Região AWS |
| `TF_STATE_BUCKET` | Secret | Backend S3 e leitura do state do `oficina-infra-db` |
| `TF_VAR_eks_cluster_role_arn` | Secret | ARN da role IAM pré-existente do control plane EKS |
| `TF_VAR_eks_node_role_arn` | Secret | ARN da role IAM pré-existente do node group |
| `PROJECT_NAME` | Variable opcional | Prefixo lógico; padrão `oficina` |
| `ENVIRONMENT` | Variable opcional | Ambiente; padrão `dev` |
| `EKS_CLUSTER_NAME` | Variable opcional | Nome do cluster; padrão `oficina-eks` |
| `ECR_REPOSITORY_NAME` | Variable opcional | Nome do ECR; padrão `oficina-api` |
| `LOAD_BALANCER_PROVISIONING_MODE` | Variable opcional | `terraform_nlb` padrão ou `aws_lbc` |
| `API_NODE_PORT` | Variable opcional | NodePort da API; padrão `30080` |
| `TF_VAR_aws_load_balancer_controller_iam_mode` | Variable opcional | `node` ou `irsa`, usado apenas no modo `aws_lbc` |
| `AUTH_FUNCTION_NAME` | Variable opcional | Lambda Auth; padrão `oficina-auth-cpf` |
| `AUTHORIZER_FUNCTION_NAME` | Variable opcional | Lambda Authorizer; padrão `oficina-jwt-authorizer` |

O range NodePort `30000-32767` deve permitir apenas tráfego interno da VPC. A regra existente usa o CIDR da VPC e nunca deve ser alterada para `0.0.0.0/0`.

## Como executar

### Core (passo 2)

Pull requests executam `Terraform Check`, com `fmt`, `init -backend=false` e `validate`.

Após o merge na `main`, execute manualmente:

```text
GitHub Actions > Terraform Apply > Run workflow
```

No modo `terraform_nlb`, o job de addons é **ignorado automaticamente**. O Target Group pode ficar sem targets saudáveis até o deploy da `oficina-api`; isso é esperado e não deve falhar o apply do core.

No modo `aws_lbc`, o mesmo workflow também aplica os addons (AWS Load Balancer Controller via Helm).

### API Gateway (passo 5)

Após o deploy da API e das Lambdas, execute:

```text
GitHub Actions > Terraform API Gateway Apply > Run workflow
```

## Como validar pela AWS

### Após o core (passo 2)

Console:

- Em EKS, confirme cluster e node group ativos.
- Em ECR, confirme o repositório da API.
- Em EC2 Load Balancers, no modo `terraform_nlb`, confirme NLB interno.
- Em SSM Parameter Store, no modo `terraform_nlb`, confirme `/${PROJECT_NAME}/${ENVIRONMENT}/api/backend-listener-arn`.
- Em Security Groups, confirme NodePort restrito ao CIDR da VPC.

CLI:

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

### Após o API Gateway (passo 5)

Console:

- Em API Gateway, confirme HTTP API, VPC Link e rotas (`POST /api/auth/cpf`, `GET /health`, `ANY /api/{proxy+}`).
- Em SSM Parameter Store, confirme `/${PROJECT_NAME}/${ENVIRONMENT}/api/public-base-url`.

CLI:

```powershell
aws apigatewayv2 get-apis --region $env:AWS_REGION --query "Items[?contains(Name,'$($env:PROJECT_NAME)')].{Nome:Name,Protocolo:ProtocolType,URL:ApiEndpoint}"
aws ssm get-parameter --name "/$($env:PROJECT_NAME)/$($env:ENVIRONMENT)/api/public-base-url" --region $env:AWS_REGION --query "Parameter.Value" --output text
```

## Como validar localmente

Execute apenas validações não destrutivas:

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
```

## Próxima etapa

No modo `terraform_nlb`, executar `oficina-api`. No modo `aws_lbc`, executar addons antes da API. Depois publicar `oficina-auth-lambda` e voltar a este repositório para aplicar `terraform/api-gateway`.
