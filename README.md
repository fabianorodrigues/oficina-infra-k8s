# oficina-infra-k8s

## Visão geral

Este repositório provisiona a infraestrutura Kubernetes da solução Oficina API. Ele consome a VPC e as subnets criadas pelo `oficina-infra-db` e entrega o Amazon ECR e o cluster Amazon EKS usados pelo deploy da API.

O deploy da aplicação não é feito aqui; ele pertence ao repositório `oficina-api`.

## Arquitetura e ordem de implantação

1. `oficina-infra-db`: cria VPC, subnets, security groups e RDS.
2. **`oficina-infra-k8s`**: cria ECR, EKS e node group.
3. `oficina-api`: publica a imagem no ECR, executa migrations e sobe no EKS.
4. `oficina-auth-lambda`: publica as Lambdas de autenticação e autorização.
5. **`oficina-infra-k8s`**: etapa futura para API Gateway.

## Responsabilidade deste repositório

- Provisionar o repositório ECR `oficina-api`.
- Provisionar o cluster EKS `oficina-eks`.
- Provisionar o node group `oficina-node-group`.
- Gerar outputs usados pelo deploy da API.
- Preparar a base para a etapa futura de API Gateway.

## Integração com os outros repositórios

Este repositório consome a rede criada pelo `oficina-infra-db` e gera a infraestrutura usada pelo `oficina-api`.

### Valores consumidos

| Valor | Origem | Formato esperado |
|---|---|---|
| `TF_VAR_vpc_id` | Output `vpc_id` do `oficina-infra-db` | String, exemplo `vpc-abc` |
| `TF_VAR_subnet_ids` | Output `subnet_ids` do `oficina-infra-db` | Lista JSON, exemplo `["subnet-abc","subnet-def"]` |

### Valores gerados

| Output | Usado por | Como configurar |
|---|---|---|
| `ecr_repository_url` | `oficina-api` | `ECR_REPOSITORY_URL` com a URL completa do ECR |
| `cluster_name` | `oficina-api` | `EKS_CLUSTER_NAME` |
| `cluster_endpoint` | Validação operacional | Referência do cluster |
| `node_group_name` | Validação operacional | Referência do node group |

`ecr_repository_url` deve ter o formato completo `<account-id>.dkr.ecr.<region>.amazonaws.com/oficina-api`. Esse valor não é senha, mas expõe conta AWS, região e nome do repositório; por isso, neste projeto, ele pode ser mantido como GitHub Secret no `oficina-api`.

Quando API Gateway for implementado, este repositório também deverá consumir a URL pública da API e os nomes ou ARNs das Lambdas de autenticação.

## Configuração necessária

Configure os valores em `GitHub > Settings > Secrets and variables > Actions`.

| Nome | Tipo | Uso |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Secret | Autenticar na AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Autenticar na AWS |
| `AWS_SESSION_TOKEN` | Secret opcional | Autenticar com credencial temporária |
| `AWS_REGION` | Secret | Região AWS, exemplo `us-east-1` |
| `TF_STATE_BUCKET` | Secret | Bucket S3 do Terraform State remoto |
| `TF_VAR_vpc_id` | Secret ou Variable | VPC onde o EKS será criado |
| `TF_VAR_subnet_ids` | Secret ou Variable | Subnets usadas pelo EKS |
| `TF_VAR_eks_cluster_role_arn` | Secret ou Variable | Role do control plane do EKS |
| `TF_VAR_eks_node_role_arn` | Secret ou Variable | Role do node group |
| `IMAGE_ALIAS_TAG` | Variable opcional | Alias mutável permitido no ECR; padrão `latest` |

Exemplos de ARNs:

```text
arn:aws:iam::<account-id>:role/<eks-cluster-role>
arn:aws:iam::<account-id>:role/<eks-node-role>
```

## Como executar

Em Pull Requests, o workflow `Terraform Check` valida formatação e configuração Terraform.

Após o merge na `main`, execute manualmente:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow prepara o backend remoto, executa `terraform plan`, aplica a infraestrutura e exibe os outputs de ECR e EKS.

## Como validar

Configure o kubeconfig:

```powershell
aws eks update-kubeconfig --name <cluster_name> --region <region>
```

Valide o cluster, os nodes e o ECR:

```powershell
kubectl get nodes
aws ecr describe-repositories --repository-names oficina-api --region <region>
terraform output
```

Resultado esperado:

- cluster EKS com status `ACTIVE`;
- node group com status `ACTIVE`;
- repositório ECR `oficina-api` criado;
- ECR com tag mutability imutável e exceção operacional para `latest`.

## Problemas comuns

| Problema | Possível causa | Como resolver |
|---|---|---|
| `TF_VAR_vpc_id` inválido | Valor copiado incorretamente do `oficina-infra-db` | Copie o output `vpc_id` novamente |
| `TF_VAR_subnet_ids` inválido | Lista fora do formato JSON | Use o formato `["subnet-abc","subnet-def"]` |
| EKS falha por role | ARN incorreto ou role sem permissões | Revise `TF_VAR_eks_cluster_role_arn` e `TF_VAR_eks_node_role_arn` |
| `kubectl get nodes` sem acesso | Kubeconfig não atualizado | Rode `aws eks update-kubeconfig` |
| Push da API falha no ECR | Secret ausente no `oficina-api` | Configure `ECR_REPOSITORY_URL` com `ecr_repository_url` |

## Próxima etapa

Siga para o repositório `oficina-api`, configure `ECR_REPOSITORY_URL` e `EKS_CLUSTER_NAME`, publique a imagem no ECR e implante a aplicação no EKS.
