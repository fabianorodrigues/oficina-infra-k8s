provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "newrelic" {
  account_id = local.new_relic_account_id
  api_key    = var.enable_new_relic ? var.new_relic_user_api_key : "disabled"
  region     = local.new_relic_region
}

data "aws_eks_cluster" "this" {
  count = var.enable_new_relic ? 1 : 0

  name = local.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  count = var.enable_new_relic ? 1 : 0

  name = local.cluster_name
}

provider "kubernetes" {
  host                   = var.enable_new_relic ? data.aws_eks_cluster.this[0].endpoint : "https://127.0.0.1"
  cluster_ca_certificate = var.enable_new_relic ? base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data) : ""
  token                  = var.enable_new_relic ? data.aws_eks_cluster_auth.this[0].token : ""
}

provider "helm" {
  kubernetes {
    host                   = var.enable_new_relic ? data.aws_eks_cluster.this[0].endpoint : "https://127.0.0.1"
    cluster_ca_certificate = var.enable_new_relic ? base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data) : ""
    token                  = var.enable_new_relic ? data.aws_eks_cluster_auth.this[0].token : ""
  }
}
