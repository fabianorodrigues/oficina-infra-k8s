# oficina-infra-k8s

## Visão Geral

Este repositório provisiona os recursos de Kubernetes e exposição pública da solução Oficina. Ele mantém três roots Terraform:

- `terraform`: ECR, EKS, node group, OIDC provider e IAM para o AWS Load Balancer Controller.
- `terraform/addons`: instalação do AWS Load Balancer Controller via Helm e IRSA.
- `terraform/api-gateway`: HTTP API com VPC Link para a API privada no EKS.

Os valores padrão são adequados para ambiente de validação e podem ser ajustados conforme a necessidade. NAT não é obrigatório no padrão atual e Secrets Manager será avaliado em etapa futura.

## Responsabilidade

- Criar o repositório ECR da API.
- Criar o cluster EKS e o node group mínimo.
- Usar `public_subnet_ids` para o node group mínimo.
- Preparar IRSA para o AWS Load Balancer Controller.
- Instalar o AWS Load Balancer Controller em etapa de addons.
- Criar o API Gateway HTTP API com VPC Link usando `private_subnet_ids`.

## Ordem De Implantação

1. `oficina-infra-db`
2. `oficina-infra-k8s` core
3. `oficina-infra-k8s` addons
4. `oficina-api`
5. `oficina-auth-lambda`
6. `oficina-infra-k8s` API Gateway
7. Novo deploy da `oficina-api` com `EMAIL_BASE_URL_APROVA_RECUSA_ORCAMENTO`

## Configuração Necessária

Configure no GitHub Actions:

| Nome | Tipo | Uso |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | Secret | Autenticação AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Autenticação AWS |
| `AWS_SESSION_TOKEN` | Secret opcional | Credenciais temporárias |
| `AWS_REGION` | Secret | Região AWS |
| `TF_STATE_BUCKET` | Secret | Bucket S3 do Terraform state |
| `TF_VAR_eks_cluster_role_arn` | Secret | Role do cluster EKS |
| `TF_VAR_eks_node_role_arn` | Secret | Role do node group |

O core consome automaticamente a rede criada pelo `oficina-infra-db` via remote state. Não é necessário informar VPC ou subnets manualmente no fluxo padrão.

As credenciais AWS usadas nos workflows devem ter permissão para ECR, EKS, IAM/IRSA do controller, Helm/Kubernetes via cluster, API Gateway, VPC Link, Lambda permissions e SSM conforme o root executado.
## Como Executar Na AWS

Execute o workflow manual:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow aplica primeiro o root core e depois o root `terraform/addons`. A instalação do AWS Load Balancer Controller ocorre somente depois que o cluster está ativo e acessível.

Depois do deploy da API e das Lambdas, execute:

```text
GitHub Actions > Terraform API Gateway Apply > Run workflow
```

## Como Validar Na AWS

Valide pelo próprio workflow:

- EKS e ECR criados no core.
- Deployment `aws-load-balancer-controller` disponível no namespace `kube-system`.
- API Gateway criado somente após o Listener ARN ter sido gravado pelo deploy da API.


## Como Validar Localmente

Execute validações não destrutivas:

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

## Valores Consumidos

| Valor | Origem | Uso |
| --- | --- | --- |
| `vpc_id` | Remote state do `oficina-infra-db` | Cluster, controller e VPC Link |
| `vpc_cidr_block` | Remote state do `oficina-infra-db` | Regras internas de segurança |
| `public_subnet_ids` | Remote state do `oficina-infra-db` | Node group mínimo |
| `private_subnet_ids` | Remote state do `oficina-infra-db` | NLB interno e VPC Link |
| `/oficina/{environment}/api/backend-listener-arn` | SSM | Integração privada do API Gateway |

## Valores Gerados

| Valor | Destino | Uso |
| --- | --- | --- |
| ECR repository | - | Publicação da imagem da API |
| Cluster EKS | - | Deploy da API |
| IAM Role do controller | Remote state do core | Instalação do addon |
| `/oficina/{environment}/api/public-base-url` | SSM | URL pública usada pela API em novo deploy |

## Próxima Etapa

Após o core e os addons, faça o deploy da `oficina-api`, publique o `oficina-auth-lambda`, aplique o root `api-gateway` e execute novo deploy da API para consumir a URL pública do API Gateway.
