# oficina-infra-k8s

## Visão geral

Este repositório provisiona a infraestrutura Kubernetes da Oficina API. Ele é a **etapa 2** da implantação, logo após o `oficina-infra-db`.

O Terraform cria o Amazon ECR e o cluster EKS. Em uma etapa posterior, este repositório também será usado para provisionar o API Gateway. O deploy da aplicação não é feito aqui; ele pertence ao `oficina-api`.

## Ordem de implantação da solução

1. `oficina-infra-db`
2. **`oficina-infra-k8s`**
3. `oficina-api`
4. `oficina-auth-lambda`
5. **`oficina-infra-k8s` novamente para API Gateway**, quando essa etapa estiver implementada

## Responsabilidade

Este repositório é responsável por:

- provisionar o repositório ECR `oficina-api`;
- provisionar o cluster EKS `oficina-eks`;
- provisionar o node group `oficina-node-group`;
- expor outputs usados pelo `oficina-api`;
- futuramente, provisionar o API Gateway `oficina-api-gateway`.

## Pré-requisitos

- `oficina-infra-db` aplicado com sucesso.
- Outputs `vpc_id` e `subnet_ids` do `oficina-infra-db`.
- Conta AWS com permissões para ECR, EKS, EC2 tags, IAM pass role e S3.
- IAM Roles compatíveis com EKS control plane e node group.
- Terraform instalado para validação local.
- AWS CLI e `kubectl` instalados para validação.

## Configuração necessária

Configure os valores em `GitHub > Settings > Secrets and variables > Actions`.

| Nome | Tipo | Origem | Onde configurar | Uso |
|---|---|---|---|---|
| `AWS_ACCESS_KEY_ID` | Secret | Credencial AWS do usuário | GitHub Secrets deste repo | Autenticar na AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Credencial AWS do usuário | GitHub Secrets deste repo | Autenticar na AWS |
| `AWS_SESSION_TOKEN` | Secret | Credencial temporária, se aplicável | GitHub Secrets deste repo | Autenticar com sessão temporária |
| `AWS_REGION` | Secret | Região escolhida, por exemplo `us-east-1` | GitHub Secrets deste repo | Definir região do Terraform e AWS CLI |
| `TF_STATE_BUCKET` | Secret | Nome de bucket S3 escolhido pelo usuário | GitHub Secrets deste repo | Armazenar Terraform State remoto |
| `TF_VAR_vpc_id` | Secret ou Variable | Output `vpc_id` do `oficina-infra-db` | GitHub Secrets ou Variables deste repo | VPC onde o EKS será criado |
| `TF_VAR_subnet_ids` | Secret ou Variable | Output `subnet_ids` do `oficina-infra-db` | GitHub Secrets ou Variables deste repo | Subnets usadas pelo EKS |
| `TF_VAR_eks_cluster_role_arn` | Secret ou Variable | ARN criado pelo usuário | GitHub Secrets ou Variables deste repo | Role do control plane do EKS |
| `TF_VAR_eks_node_role_arn` | Secret ou Variable | ARN criado pelo usuário | GitHub Secrets ou Variables deste repo | Role do node group |
| `IMAGE_ALIAS_TAG` | Variable opcional | Valor definido pelo usuário | GitHub Variables deste repo | Alias mutável permitido no ECR; padrão `latest` |

Exemplos de ARNs:

```text
arn:aws:iam::<account-id>:role/<eks-cluster-role>
arn:aws:iam::<account-id>:role/<eks-node-role>
```

`latest` é apenas um alias operacional mutável. A rastreabilidade da imagem publicada pelo `oficina-api` é feita pela tag `${GITHUB_SHA}`.

## Como executar

1. Abra um Pull Request para `main`.
2. Aguarde o workflow `Terraform Check`.
3. Após aprovação, faça merge na `main`.
4. Execute manualmente:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow `Terraform Check` roda em Pull Request e executa:

```powershell
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

O workflow `Terraform Apply` é manual e executa:

- validação de secrets e variables obrigatórios;
- criação ou validação do bucket S3 do state;
- `terraform init` com backend remoto;
- `terraform plan -out=tfplan`;
- `terraform apply -auto-approve tfplan`;
- exibição dos outputs de ECR e EKS;
- validação básica do cluster, node group e ECR.

## Como validar

Configure o kubeconfig:

```powershell
aws eks update-kubeconfig --name <cluster_name> --region <region>
```

Valide os nodes:

```powershell
kubectl get nodes
```

Valide o ECR:

```powershell
aws ecr describe-repositories --repository-names oficina-api --region <region>
```

Valide os outputs:

```powershell
terraform output
```

Resultado esperado:

- cluster EKS com status `ACTIVE`;
- node group com status `ACTIVE`;
- repositório ECR `oficina-api` criado;
- tag mutability do ECR imutável com exceção somente para `latest`.

## Outputs para a próxima etapa

| Output | Usado por | Configurar como |
|---|---|---|
| `ecr_repository_url` | `oficina-api` | `ECR_REPOSITORY_URL` |
| `cluster_name` | `oficina-api` | `EKS_CLUSTER_NAME` |
| `cluster_endpoint` | Validação operacional | Referência do cluster |
| `node_group_name` | Validação operacional | Referência do node group |

Quando API Gateway for implementado, esta etapa deverá receber:

| Entrada futura | Origem esperada | Uso |
|---|---|---|
| `api_load_balancer_url` | Serviço Kubernetes publicado pelo `oficina-api` | Integração do API Gateway com a API |
| Nome ou ARN da Lambda Auth | `oficina-auth-lambda` | Rota pública de autenticação |
| Nome ou ARN da Lambda Authorizer | `oficina-auth-lambda` | Autorização JWT |

O output esperado para essa etapa futura será `api_gateway_url`.

## Problemas comuns

| Problema | Possível causa | Como resolver |
|---|---|---|
| `TF_VAR_vpc_id` inválido | Valor copiado incorretamente do `oficina-infra-db` | Copie o output `vpc_id` novamente |
| `TF_VAR_subnet_ids` inválido | Lista fora do formato Terraform/JSON | Use formato `["subnet-abc","subnet-def"]` |
| EKS falha por role | ARN incorreto ou role sem permissões | Revise `TF_VAR_eks_cluster_role_arn` e `TF_VAR_eks_node_role_arn` |
| `kubectl get nodes` sem acesso | Kubeconfig não atualizado | Rode `aws eks update-kubeconfig` |
| Push da API falha no ECR | Secret ausente no `oficina-api` | Configure `ECR_REPOSITORY_URL` com o output deste repo |

## Próxima etapa

Siga para o repositório `oficina-api`, configure `ECR_REPOSITORY_URL` e `EKS_CLUSTER_NAME`, publique a imagem no ECR e implante a aplicação no EKS.
