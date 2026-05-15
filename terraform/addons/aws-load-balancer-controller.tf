resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_chart_version
  namespace  = "kube-system"

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 600

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = local.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  dynamic "set_sensitive" {
    for_each = local.aws_load_balancer_controller_irsa_enabled ? [1] : []

    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = coalesce(local.aws_load_balancer_controller_role_arn, "")
    }
  }

  lifecycle {
    precondition {
      condition = (
        !local.aws_load_balancer_controller_irsa_enabled ||
        try(local.aws_load_balancer_controller_role_arn != null && length(trimspace(nonsensitive(local.aws_load_balancer_controller_role_arn))) > 0, false)
      )
      error_message = "aws_load_balancer_controller_role_arn e obrigatorio no remote state do core quando aws_load_balancer_controller_iam_mode = irsa."
    }
  }
}
