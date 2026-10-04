variable "environment" {
  type = string
}

variable "region" {
  type        = string
  description = "ACM region. us-west-1 for regional API Gateway; us-east-1 is handled by modules/ssl."
}

variable "hosted_zone_id" {
  type = string
}

variable "root_domains" {
  type = list(object({
    domain     = string
    subdomains = list(string)
  }))
}
