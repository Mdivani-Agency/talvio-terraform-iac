variable "region" {
  type    = string
  default = "us-west-1"
}

variable "environment" {
  type = string
}

variable "parameters" {
  type = map(object({
    value       = string
    type        = optional(string, "SecureString")
    description = optional(string)
    tags        = optional(map(string))
    prefix      = optional(string, "config")
    })
  )
}
