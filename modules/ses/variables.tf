variable "environment" {
  type = string
}

variable "ses_from_mail" {
  type = string
}

variable "create_ses_domain" {
  type    = bool
  default = false
}

variable "ses_domain" {
  type = string
}

variable "hosted_zone_id" {
  type = string
}

variable "ses_email_from_subdomain" {
  type = string
}

variable "spf_directive_value" {
  type = string
}

variable "dmarc_directive_value" {
  type = string
}

variable "dkim_directive_value" {
  type = string
}

variable "ses_templates" {}

variable "origin_domain_servers" {}

variable "use_origin_domain_servers" {
  default = false
  type    = bool
}
