resource "aws_lb" "quay_alb" {
  name               = "${var.prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.db_security_group.id]
  subnets            = module.quay_vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Environment = "${var.prefix}"
  }
}

resource "aws_lb_listener" "quay_http" {
  load_balancer_arn = "${aws_lb.quay_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "quay_alb_https_listener" {
  load_balancer_arn = aws_lb.quay_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.quay_domain_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.quay_alb_https_target_group.arn
  }
}

resource "aws_alb_target_group" "quay_alb_https_target_group" {
  name     = "${var.prefix}-alb-https-tg"
  port     = "443"
  protocol = "HTTPS"
  target_type = "ip"
  vpc_id   = module.quay_vpc.vpc_id
}


resource "aws_alb_listener" "quay_alb_grpc_listener" {
  load_balancer_arn = aws_lb.quay_alb.arn
  port              = "55443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.quay_domain_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.quay_alb_grpc_target_group.arn
  }
}

resource "aws_alb_target_group" "quay_alb_grpc_target_group" {
  name     = "${var.prefix}-alb-grpcs-tg"
  port     = "55443"
  protocol = "HTTPS"
  target_type = "ip"
  vpc_id   = module.quay_vpc.vpc_id
  health_check {
     port = 443
  }
}

resource "aws_alb_listener" "quay_alb_metrics_listener" {
  load_balancer_arn = aws_lb.quay_alb.arn
  port              = "9091"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.quay_domain_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.quay_alb_grpc_target_group.arn
  }
}

resource "aws_alb_target_group" "quay_alb_metrics_target_group" {
  name     = "${var.prefix}-alb-metrics-tg"
  port     = "9091"
  protocol = "HTTPS"
  target_type = "ip"
  vpc_id   = module.quay_vpc.vpc_id
  health_check {
     port = 443
  }
}

/* TODO: Add IPs of ELB automatically to the target group */
#
data "aws_resourcegroupstaggingapi_resources" "quay_elb" {
  resource_type_filters = ["elasticloadbalancing:loadbalancer"]
  depends_on = [ null_resource.kubectl_apply ]
  tag_filter {
    key = "kubernetes.io/service-name"
    values = ["${var.prefix}-quay/${var.prefix}-quay-lb"]
  }
}

# Save randomly generated name of quay ELB
locals {
  quay_elb_name = split("/", data.aws_resourcegroupstaggingapi_resources.quay_elb.resource_tag_mapping_list[0].resource_arn)[1] 
}
# Use ELB name to find network interfaces
data "aws_network_interfaces" "quay_elb_nics" {
  depends_on = [ null_resource.kubectl_apply ]
  filter {
    name = "description"
    values = ["ELB ${local.quay_elb_name}"]
  }
}

data "aws_network_interface" "quay_elb_nics" {
  depends_on = [ null_resource.kubectl_apply ]
  count = var.run_alb_attachment ? length(data.aws_network_interfaces.quay_elb_nics.ids) : 0
  id = data.aws_network_interfaces.quay_elb_nics.ids[count.index]
  # for_each = toset(data.aws_network_interfaces.quay_elb_nics.ids)
  # id = each.value
}

# Want to attach each private ip to the target group for https
resource "aws_lb_target_group_attachment" "quay_lb_https_attachment" {
  depends_on = [ null_resource.kubectl_apply, data.aws_network_interface.quay_elb_nics]
  # for_each = {
  #   for k, v in data.aws_network_interface.quay_elb_nics :
  #   v.id => v
  # }
  count = var.run_alb_attachment ? length(data.aws_network_interface.quay_elb_nics) : 0
  target_group_arn = aws_alb_target_group.quay_alb_https_target_group.arn
  availability_zone = "all"
  target_id = data.aws_network_interface.quay_elb_nics[count.index].private_ip
}
