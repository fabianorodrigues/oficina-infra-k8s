# oficina-infra-k8s

## Visão geral

Este repositório concentra a infraestrutura cloud/Kubernetes da Oficina API e faz parte da Fase 3 do Tech Challenge FIAP.

## Responsabilidade deste repositório

Este repositório é responsável por:

- Amazon ECR da API;
- Cluster EKS;
- Manifests Kubernetes;
- Deploy da API;
- Migration job;
- API Gateway;
- Integração com Lambdas e observabilidade.
- 
## Arquitetura atual

Fluxo atual:

```text
oficina-api
  -> Docker build
  -> Amazon ECR criado por este repositório
```

O Terraform deste repositório cria o ECR. Depois do provisionamento, o output `ecr_repository_url` deve ser configurado como secret `ECR_REPOSITORY_URL` no repositório `oficina-api`.

O workflow futuro do `oficina-api` publicará imagens no ECR com:

- tag `demo-latest`, usada para a versão mais recente de demonstração;
- tag única com SHA do commit, usada para rastreabilidade.

## Recursos provisionados

| Recurso | Descrição |
|---|---|
| Amazon ECR | Repositório de imagem Docker da `oficina-api` |
| S3 Backend | Bucket usado para armazenar o Terraform State |

## Secrets necessários

Configure os secrets em:

```text
GitHub > Settings > Secrets and variables > Actions
```

| Secret | Descrição | Exemplo |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Access Key do AWS Academy | não versionar |
| `AWS_SECRET_ACCESS_KEY` | Secret Key do AWS Academy | não versionar |
| `AWS_SESSION_TOKEN` | Token temporário do AWS Academy | expira |
| `AWS_REGION` | Região AWS | `<aws-region>` |
| `TF_STATE_BUCKET` | Bucket S3 para o Terraform State | `<bucket-tfstate>` |

## Workflows

### Terraform Check

O workflow `Terraform Check`:

- roda em Pull Request para `main`;
- valida a formatação e a sintaxe do Terraform.

Comandos executados:

```powershell
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

### Terraform Apply

O workflow `Terraform Apply`:

- é executado manualmente;
- usa credenciais AWS;
- garante que o bucket S3 para o Terraform State exista;
- executa `terraform init`;
- executa `terraform plan`;
- executa `terraform apply -auto-approve`;
- exibe os outputs do ECR.

## Como executar

### 1. Abrir Pull Request

Crie uma branch com as alterações de infraestrutura e abra um Pull Request para `main`.

Antes do merge, valide que o workflow `Terraform Check` ficou verde. Faça merge somente após o sucesso desse workflow.

### 2. Executar apply manual

Depois do merge na `main`, execute:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow criará o ECR e exibirá os outputs ao final da execução.

## Outputs

Outputs esperados após o `Terraform Apply`:

| Output | Uso |
|---|---|
| `ecr_repository_name` | Nome do repositório ECR |
| `ecr_repository_url` | URL usada pelo repo `oficina-api` para publicar imagem |
| `ecr_registry_id` | ID do registry AWS |

Copie o valor de `ecr_repository_url` e configure no repositório `oficina-api` como secret:

```text
ECR_REPOSITORY_URL=<ecr_repository_url>
```

## Como validar

### Pela AWS CLI

Execute:

```powershell
aws ecr describe-repositories --repository-names oficina-api --region us-east-1
```

Resultado esperado:

- `repositoryName`: `oficina-api`;
- `repositoryUri` preenchido.

### Pelo Console AWS

Acesse:

```text
AWS Console > ECR > Private repositories > oficina-api
```

Valide:

- repositório criado;
- scan on push habilitado;
- política de lifecycle configurada, se disponível.
