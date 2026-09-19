variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "dynamo_db_tables" {
  type = map(object({
    hash_key                    = optional(string, "id")
    range_key                   = optional(string)
    point_in_time_recovery      = optional(bool, false)
    deletion_protection_enabled = optional(bool, false)
    stream_enabled              = optional(bool, false)
    stream_view_type            = optional(string)
    attributes                  = optional(map(string), {})
    global_secondary_indexes = optional(map(object({
      hash_key           = string
      range_key          = optional(string)
      projection_type    = optional(string)
      non_key_attributes = optional(list(string))
    })), {})
    ttl = optional(object({
      attribute_name = string
      enabled        = bool
    }), null)
  }))
  description = "Map with the dynamo db tables"
  default     = {}
}
