resource "aws_lb" "api" {
  count = local.nlb_provisioning_enabled ? 1 : 0

  name               = "${var.project_name}-${var.environment}-api-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = local.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-nlb"
    Application = "oficina-api"
  }
}

resource "aws_lb_target_group" "api" {
  count = local.nlb_provisioning_enabled ? 1 : 0

  name        = "${var.project_name}-${var.environment}-api-tg"
  port        = var.api_node_port
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = local.vpc_id

  health_check {
    enabled  = true
    path     = var.api_health_check_path
    port     = tostring(var.api_node_port)
    protocol = "HTTP"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-tg"
    Application = "oficina-api"
  }
}

resource "aws_lb_listener" "api" {
  count = local.nlb_provisioning_enabled ? 1 : 0

  load_balancer_arn = aws_lb.api[0].arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api[0].arn
  }
}

resource "aws_autoscaling_attachment" "api_nodeport" {
  count = local.nlb_provisioning_enabled ? 1 : 0

  autoscaling_group_name = aws_eks_node_group.this.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.api[0].arn
}

resource "aws_ssm_parameter" "backend_listener_arn" {
  count = local.nlb_provisioning_enabled ? 1 : 0

  name      = "/${var.project_name}/${var.environment}/api/backend-listener-arn"
  type      = "String"
  value     = aws_lb_listener.api[0].arn
  overwrite = true

  tags = {
    Name        = "/${var.project_name}/${var.environment}/api/backend-listener-arn"
    Application = "oficina-api"
  }
}
