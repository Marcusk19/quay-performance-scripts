provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory" # uncomment for prod certs
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory" # uncomment for stage certs
}
resource "tls_private_key" "quay_lb_cert_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_private_key" "acme_private_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "quay_lb_cert" {
  private_key_pem = "${tls_private_key.quay_lb_cert_key.private_key_pem}"

  subject {
    common_name="${local.quay_hostname}"
    organization = "RedHat"
  }

  dns_names = ["${local.quay_hostname}"]
  is_ca_certificate=true
  validity_period_hours = 12000

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "acme_registration" "quay_acme_registration" {
  account_key_pem = tls_private_key.acme_private_key.private_key_pem
  email_address = var.email_address
}

resource "acme_certificate" "quay_acme_certificate" {
  account_key_pem = acme_registration.quay_acme_registration.account_key_pem
  common_name = var.dns_domain
  subject_alternative_names = ["*.${var.dns_domain}"]

  dns_challenge {
    provider = "route53"

    config = {
      AWS_HOSTED_ZONE_ID = data.aws_route53_zone.zone.zone_id
    }
  }

  depends_on  = [acme_registration.quay_acme_registration]
}


resource "aws_acm_certificate" "quay_domain_cert" {
  certificate_body = acme_certificate.quay_acme_certificate.certificate_pem
  private_key  = acme_certificate.quay_acme_certificate.private_key_pem
  certificate_chain = acme_certificate.quay_acme_certificate.issuer_pem
  tags = {
    Environment = var.prefix
  }
  # domain_name       = var.dns_domain 
}

# resource "aws_route53_record" "quay_cert_validation_record" {
#   for_each = {
#     for dvo in aws_acm_certificate.quay_domain_cert.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }
#
#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.zone.zone_id
# }
#
# resource "aws_acm_certificate_validation" "quay_cert_validation" {
#   certificate_arn         = aws_acm_certificate.quay_domain_cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.quay_cert_validation_record : record.fqdn]
# }
