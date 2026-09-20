variable "environment" {
  type = string
}

variable "region" {
  type = string
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
