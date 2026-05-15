# oficina-infra-k8s

## Visão Geral

Este repositório provisiona a camada Kubernetes e a entrada pública da solução Oficina. Ele contém três roots Terraform:

- `terraform`: ECR, EKS, node group e configuração IAM opcional do AWS Load Balancer Controller.
- `terraform/addons`: instalação do AWS Load Balancer Controller via Helm em modo `node` ou `irsa`.
- `terraform/api-gateway`: API Gateway HTTP API com VPC Link para o NLB interno da API.

## Responsabilidade Deste Repositório

- Criar o repositório ECR da API.
- Criar o cluster EKS e o node group.
- Preparar e instalar o AWS Load Balancer Controller.
- Criar o API Gateway, VPC Link, integrações e permissões de invocação das Lambdas.
- Publicar no SSM a URL pública do API Gateway para consumo opcional pela API.

## Integração com os Outros Repositórios

Valores consumidos:

| Valor | Origem | Uso |
| --- | --- | --- |
| `TF_STATE_BUCKET` | GitHub Secret | Backend S3 e leitura de remote states |
| `vpc_id`, `vpc_cidr_block` e subnets | `oficina-infra-db` | EKS, NLB interno e VPC Link |
| `TF_VAR_eks_cluster_role_arn` | Secret ou Variable | Role existente do control plane do EKS |
| `TF_VAR_eks_node_role_arn` | Secret ou Variable | Role existente do node group |
| `TF_VAR_aws_load_balancer_controller_iam_mode` | Variable opcional | Modo IAM do AWS Load Balancer Controller; padrão `node` |
| `/oficina/{environment}/api/backend-listener-arn` | SSM gerado pelo `oficina-api` | Backend privado do API Gateway |
| Lambdas publicadas | `oficina-auth-lambda` | Autenticação e authorizer do API Gateway |

Valores gerados:

| Valor | Consumido por | Uso |
| --- | --- | --- |
| ECR repository URL | `oficina-api` | Publicação da imagem Docker |
| Cluster EKS | `oficina-api` | Deploy dos workloads |
| AWS Load Balancer Controller | `oficina-api` | Criação do NLB interno |
| API Gateway HTTP API | Clientes externos | Entrada pública da solução |
| `/oficina/{environment}/api/public-base-url` | `oficina-api` | URL pública opcional para links de e-mail |

## Ordem de Implantação

1. `oficina-infra-db`
2. `oficina-infra-k8s` core
3. `oficina-infra-k8s` addons
4. `oficina-api`
5. `oficina-auth-lambda`
6. `oficina-infra-k8s` API Gateway

## Configuração Necessária

Configure no GitHub Actions:

| Nome | Tipo | Uso |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | Secret | Autenticação AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Autenticação AWS |
| `AWS_SESSION_TOKEN` | Secret opcional | Credenciais temporárias |
| `AWS_REGION` | Secret | Região AWS |
| `TF_STATE_BUCKET` | Secret | Nome do bucket S3 para state remoto |
| `TF_VAR_eks_cluster_role_arn` | Secret ou Variable | Role existente do cluster EKS |
| `TF_VAR_eks_node_role_arn` | Secret ou Variable | Role existente do node group |
| `TF_VAR_aws_load_balancer_controller_iam_mode` | Variable opcional | `node` ou `irsa`; padrão `node` |
| `EKS_CLUSTER_NAME` | Variable opcional | Nome do cluster; padrão `oficina-eks` |
| `ECR_REPOSITORY_NAME` | Variable opcional | Nome do ECR; padrão `oficina-api` |
| `AUTH_FUNCTION_NAME` | Variable opcional | Nome da Lambda Auth; padrão `oficina-auth-cpf` |
| `AUTHORIZER_FUNCTION_NAME` | Variable opcional | Nome da Lambda Authorizer; padrão `oficina-jwt-authorizer` |

## Modos do AWS Load Balancer Controller

O AWS Load Balancer Controller pode ser instalado em dois modos:

- `node`: usa permissões já disponíveis no ambiente ou na role dos nós. É o padrão mínimo para validar o provisionamento sem criar IAM OIDC Provider, IAM Policy ou IAM Role adicionais.
- `irsa`: cria OIDC Provider, IAM Role, IAM Policy e attachment dedicados para o controller. É o modo mais isolado, mas exige permissões para criar recursos IAM/OIDC na conta.

No modo `node`, a role dos nós ou do ambiente precisa ter permissões suficientes para o AWS Load Balancer Controller criar e gerenciar NLB, Target Groups, Listeners e regras necessárias. Se essas permissões não existirem, o controller pode instalar corretamente, mas falhar ao criar o NLB interno da API.

As roles do EKS devem existir antes da execução; o workflow não as cria automaticamente. Use o mesmo `TF_STATE_BUCKET` do `oficina-infra-db`. As keys criadas automaticamente são:

| Root | Key do state |
| --- | --- |
| Core | `oficina-infra-k8s/{environment}/core/terraform.tfstate` |
| Addons | `oficina-infra-k8s/{environment}/addons/terraform.tfstate` |
| API Gateway | `oficina-infra-k8s/{environment}/api-gateway/terraform.tfstate` |

## Como Executar

Para core e addons, execute:

```text
GitHub Actions > Terraform Apply > Run workflow
```

Esse workflow aplica primeiro o core e, depois que o cluster está ativo, instala os addons.

Depois do deploy da API e das Lambdas, execute:

```text
GitHub Actions > Terraform API Gateway Apply > Run workflow
```

O API Gateway exige que o parâmetro `/oficina/{environment}/api/backend-listener-arn` já exista no SSM.

## Como Validar na AWS

Console:

- Em EKS, confirme cluster e node group ativos.
- Em ECR, confirme o repositório da API.
- No cluster, confirme o AWS Load Balancer Controller em `kube-system`.
- Em API Gateway, confirme HTTP API, VPC Link e rotas principais.
- Em SSM Parameter Store, confirme que os parâmetros esperados existam.

CLI:

```powershell
$env:AWS_REGION="<regiao>"
$env:ENVIRONMENT="<ambiente>"
$env:PROJECT_NAME="oficina"
$env:EKS_CLUSTER_NAME="<nome-do-cluster>"
$env:ECR_REPOSITORY_NAME="<nome-do-repositorio-ecr>"

aws eks describe-cluster --name $env:EKS_CLUSTER_NAME --region $env:AWS_REGION --query "cluster.{Name:name,Status:status}"
aws eks describe-nodegroup --cluster-name $env:EKS_CLUSTER_NAME --nodegroup-name "$($env:PROJECT_NAME)-node-group" --region $env:AWS_REGION --query "nodegroup.{Status:status}"
aws ecr describe-repositories --repository-names $env:ECR_REPOSITORY_NAME --region $env:AWS_REGION --query "repositories[].repositoryName"

aws eks update-kubeconfig --name $env:EKS_CLUSTER_NAME --region $env:AWS_REGION
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system

aws apigatewayv2 get-apis --region $env:AWS_REGION --query "Items[?contains(Name, 'oficina')].{Name:Name,Protocol:ProtocolType}"
aws apigatewayv2 get-vpc-links --region $env:AWS_REGION --query "Items[].{Name:Name,VpcLinkStatus:VpcLinkStatus}"
aws ssm get-parameter --name "/oficina/$($env:ENVIRONMENT)/api/public-base-url" --region $env:AWS_REGION --query "Parameter.Name"
```

## Como Executar Localmente

Execute validações não destrutivas dos três roots:

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

## Como Validar Localmente

Confirme que todos os comandos locais finalizam sem erro. A validação funcional de EKS, controller e API Gateway depende dos recursos publicados na AWS.

## Próxima Etapa

Após core e addons, executar o deploy da `oficina-api`. Depois publicar o `oficina-auth-lambda` e retornar a este repositório para aplicar o root `api-gateway`.
