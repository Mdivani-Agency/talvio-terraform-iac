variable "environment" {
  type = string
}

variable "usage_plans" {
  type = map(object({
    name        = string
    description = string
  }))
}

variable "api_keys" {
  type = map(object({
    name        = string
    description = optional(string, "Managed by Terraform")
    tags        = optional(map(string), {})
    usage_plan  = string
  }))
}
