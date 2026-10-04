variable "buckets" {
  description = "A map of S3 buckets to create."
  type = map(object({
    name = string
    tags = optional(map(string), {})
    cloudfront = optional(object({
      alias               = string
      acm_certificate_arn = optional(string, "")
      hosted_zone_id      = optional(string, "")
    }))
    enable_versioning   = optional(bool, false)
    enable_encryption   = optional(bool, false)
    logging_bucket      = optional(string, "")
    logging_prefix      = optional(string, "logs/")
    force_destroy       = optional(bool, false)
    default_root_object = optional(string, "")
    cache_policy_id     = optional(string, "658327ea-f89d-4fab-a63d-7e88639e58f6") # Managed-CachingOptimized
    price_class         = optional(string, "PriceClass_100")
  }))
}

variable "environment" {
  description = "The environment to deploy the S3 bucket to."
  type        = string
  default     = "dev"
}

variable "allowed_origins" {
  description = "The allowed origins for the S3 bucket."
  type        = list(string)
  default     = ["*"]
}
