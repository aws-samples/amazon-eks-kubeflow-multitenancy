#certificate

resource "aws_acm_certificate" "cert" {
  domain_name       = var.route53_domain
  validation_method = "DNS"
  subject_alternative_names = var.cert_alt_names

  tags = {
    Environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "theninja" {
  name = var.route53_domain
  private_zone = false
}

resource "aws_route53_record" "theninja" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.theninja.zone_id
}

resource "aws_acm_certificate_validation" "theninja" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.theninja : record.fqdn]
}


#cognito
resource "aws_cognito_user_pool" "pool" {
  depends_on                  = [aws_lambda_function.kf_profile_manager] 
  name                        = var.eks_name
  alias_attributes            = ["email", "preferred_username"]
  auto_verified_attributes    =  ["email"]
  username_configuration {
    case_sensitive            = false
  }
  
  lambda_config {
    pre_token_generation  = aws_lambda_function.kf_profile_manager.arn
    # post_authentication   = aws_lambda_function.kf_post_login.arn
  }
  

  schema {
    name = "sub"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "false"
    required = "true"
    string_attribute_constraints {
      min_length = 1
      max_length = 2048
    }
  }

  schema {
    name = "name"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "given_name"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "family_name"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "middle_name"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "nickname"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "preferred_username"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "profile"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "picture"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "website"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "email"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "true"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "email_verified"
    attribute_data_type = "Boolean"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
  }

  schema {
    name = "gender"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "birthdate"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 10
      max_length = 10
    }
  }

  schema {
    name = "zoneinfo"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "locale"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "address"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name = "updated_at"
    attribute_data_type = "Number"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    number_attribute_constraints {
      min_value = 0
    }
  }
   schema {
    name = "groups"
    attribute_data_type = "String"
    developer_only_attribute = "false"
    mutable = "true"
    required = "false"
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
}

resource "aws_route53_record" "auth-cognito-A" {
  name    = var.auth_base_domain
  type    = "A"
  zone_id = data.aws_route53_zone.theninja.zone_id
  ttl     = 60
  records = ["127.0.0.1"]
}


resource "aws_cognito_user_pool_domain" "main" {
  depends_on        = [ aws_route53_record.auth-cognito-A, aws_cognito_user_pool.pool, aws_acm_certificate.cert]
  domain            = var.cognito_domain
  certificate_arn   = aws_acm_certificate.cert.arn
  user_pool_id      = aws_cognito_user_pool.pool.id
}

resource "aws_route53_record" "auth-cognito-Auth-address" {
  name    = var.cognito_domain
  type    = "A"
  zone_id = data.aws_route53_zone.theninja.zone_id
  alias {
    evaluate_target_health = false
    name                   = aws_cognito_user_pool_domain.main.cloudfront_distribution_arn
    # This zone_id is fixed
    zone_id = "Z2FDTNDATAQYW2"
  }
}

data "template_file" "metadata_tpl" {
  template = file("./saml-metadata.xml.tpl")
}

resource "aws_cognito_identity_provider" "adfs" {
    user_pool_id  = aws_cognito_user_pool.pool.id
    provider_name = "ADFS"
    provider_type = "SAML"
    
    provider_details = {
      MetadataFile = data.template_file.metadata_tpl.rendered
      SLORedirectBindingURI = "https://${var.adfs_url}/adfs/ls/"
      SSORedirectBindingURI = "https://${var.adfs_url}/adfs/ls/"
    }
    
    # attribute_mapping = {
    #   email    = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
    # }
    attribute_mapping = {
      "email"             = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
      "email_verified"    = "https://aws.amazon.com/SAML/Attributes/validation",
      "custom:groups"     = "https://aws.amazon.com/SAML/Attributes/Role"
    }
    lifecycle {
      ignore_changes = [
        provider_details.SLORedirectBindingURI,
        provider_details.SSORedirectBindingURI,
      ]
    }
  }
  
resource "aws_cognito_user_pool_client" "client" {
  depends_on                            = [aws_cognito_identity_provider.adfs, aws_cognito_user_pool.pool]
  name                                  = var.eks_name
  user_pool_id                          = aws_cognito_user_pool.pool.id
  callback_urls                         = ["https://${var.kubeflow_domain}/oauth2/idpresponse"]
  logout_urls                           = ["https:/${var.cognito_domain}/logout?response_type=code&client_id=&redirect_uri=https://${var.kubeflow_domain}/oauth2/idpresponse&state=STATE&scope=email+openid"]
  allowed_oauth_flows                   = ["code"]
  allowed_oauth_scopes                  = ["email","openid"]
  allowed_oauth_flows_user_pool_client  = true
  supported_identity_providers          = ["ADFS"]
  generate_secret                       = true
  explicit_auth_flows                   = ["ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_CUSTOM_AUTH", "ALLOW_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors         = "ENABLED"
  read_attributes                       = ["custom:groups","address","birthdate","email","email_verified","family_name","gender","given_name","locale","middle_name","name","nickname","phone_number","phone_number_verified","picture","preferred_username","profile","zoneinfo","updated_at","website"]
  refresh_token_validity                = 7
  write_attributes                      = ["custom:groups", "address","birthdate","email","family_name","gender","given_name","locale","middle_name","name","nickname","phone_number","picture","preferred_username","profile","zoneinfo","updated_at","website"]
}

#output section

output "Cognito_user_pool_id" { value = aws_cognito_user_pool.pool.id}
output "Cognito_user_pool_arn" { value = aws_cognito_user_pool.pool.arn}
output "Cognito_user_pool_endpoint" { value = aws_cognito_user_pool.pool.endpoint}
output "Cognito_user_pool_client_id" { value = aws_cognito_user_pool_client.client.id}