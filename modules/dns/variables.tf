variable "domain" {
  type        = string
  description = "Zone name, e.g. dev.talvio.co."
}

variable "create_zone" {
  type        = bool
  description = "Create a new hosted zone. False for prod (reuse/import existing talvio.co)."
  default     = true
}

variable "existing_zone_id" {
  type        = string
  description = "Used when create_zone is false (prod import)."
  default     = ""
}

variable "comment" {
  type    = string
  default = "Managed by Terraform"
}

variable "tags" {
  type    = map(string)
  default = {}
}
