# oficina-infra-k8s

## Visão geral

Este repositório provisiona a infraestrutura Kubernetes da solução Oficina API. Ele consome a rede criada pelo `oficina-infra-db` e entrega o Amazon ECR e o cluster Amazon EKS usados pelo deploy da API.

A solução completa é composta por quatro repositórios, nesta ordem de implantação:

1. `oficina-infra-db`: rede, security groups e RDS.
2. `oficina-infra-k8s`: ECR, EKS e node group.
3. `oficina-api`: imagem Docker, migrations e deploy da API no EKS.
4. `oficina-auth-lambda`: Lambdas de autenticação por CPF e autorização JWT.

## Papel deste repositório

- Provisionar o repositório ECR `oficina-api`.
- Provisionar o cluster EKS `oficina-eks`.
- Provisionar o node group `oficina-node-group`.
- Gerar os outputs usados pelo deploy da API.
- Preparar a base para uma integração futura com API Gateway.

## Integração e dependências

Este repositório depende dos outputs do `oficina-infra-db`. Os outputs do Terraform existem para facilitar o provisionamento, a integração entre repositórios e a avaliação acadêmica do projeto como portfólio. Como podem expor metadados operacionais, como ECR, cluster, endpoint e node group, eles são tratados como sensíveis quando necessário e não são impressos nos logs do pipeline.

| Valor consumido | Origem | Formato esperado |
|---|---|---|
| `TF_VAR_vpc_id` | Output `vpc_id` do `oficina-infra-db` | String, exemplo `vpc-abc` |
| `TF_VAR_subnet_ids` | Output `subnet_ids` do `oficina-infra-db` | Lista JSON, exemplo `["subnet-abc","subnet-def"]` |

| Output gerado | Consumidor | Uso |
|---|---|---|
| `ecr_repository_url` | `oficina-api` | Configurar `ECR_REPOSITORY_URL` |
| `cluster_name` | `oficina-api` | Configurar `EKS_CLUSTER_NAME` |
| `node_group_name` | Validação operacional | Conferir o node group gerenciado |

`ecr_repository_url` deve ter o formato `<account-id>.dkr.ecr.<region>.amazonaws.com/oficina-api`. O valor não é senha, mas expõe conta AWS, região e nome do repositório; por isso pode ser mantido como GitHub Secret no `oficina-api`.

## Configuração necessária

Configure os valores em `GitHub > Settings > Secrets and variables > Actions`.

| Nome | Tipo | Uso |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Secret | Autenticar na AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Autenticar na AWS |
| `AWS_SESSION_TOKEN` | Secret opcional | Usar credenciais temporárias |
| `AWS_REGION` | Secret | Região AWS usada pelo projeto |
| `TF_STATE_BUCKET` | Secret | Bucket S3 do Terraform State remoto |
| `TF_VAR_vpc_id` | Secret recomendado | VPC criada pelo `oficina-infra-db` |
| `TF_VAR_subnet_ids` | Secret recomendado | Subnets criadas pelo `oficina-infra-db` |
| `TF_VAR_eks_cluster_role_arn` | Secret recomendado | Role do control plane do EKS |
| `TF_VAR_eks_node_role_arn` | Secret recomendado | Role do node group |
| `IMAGE_ALIAS_TAG` | Variable opcional | Alias mutável permitido no ECR; padrão `latest` |

Exemplos de ARNs:

```text
arn:aws:iam::<account-id>:role/<eks-cluster-role>
arn:aws:iam::<account-id>:role/<eks-node-role>
```

## Como executar e validar na AWS

Em Pull Requests, o workflow `Terraform Check` valida a formatação e a configuração Terraform.

Após o merge na `main`, execute manualmente:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow prepara o backend remoto, executa `terraform plan`, aplica ECR/EKS e valida cluster, node group e repositório ECR sem imprimir dados de infraestrutura nos logs.

Para validar manualmente:

```powershell
aws eks update-kubeconfig --name <cluster_name> --region <region>
kubectl get nodes
aws ecr describe-repositories --repository-names oficina-api --region <region>
terraform output -raw cluster_name
```

Resultado esperado:

- cluster EKS com status `ACTIVE`;
- node group com status `ACTIVE`;
- repositório ECR `oficina-api` criado;
- ECR com tags imutáveis e exceção operacional para `latest`.

## Problemas comuns

| Problema | Possível causa | Como resolver |
|---|---|---|
| `TF_VAR_vpc_id` inválido | Valor copiado incorretamente | Copie novamente o output `vpc_id` do `oficina-infra-db` |
| `TF_VAR_subnet_ids` inválido | Lista fora do formato JSON | Use `["subnet-abc","subnet-def"]` |
| EKS falha por role | ARN incorreto ou role sem permissões | Revise `TF_VAR_eks_cluster_role_arn` e `TF_VAR_eks_node_role_arn` |
| Push da API falha no ECR | Secret ausente no `oficina-api` | Configure `ECR_REPOSITORY_URL` com `ecr_repository_url` |

## Como executar e validar localmente

Para validação local do Terraform:

```powershell
cd oficina-infra-k8s/terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

Para consultar outputs em ambiente autenticado, use comandos explícitos e evite colar os valores em logs públicos:

```powershell
terraform output -raw ecr_repository_url
terraform output -raw cluster_name
```

Para um plano local opcional, copie o exemplo e preencha os valores reais:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform plan
```

Não versione `terraform.tfvars` real.
