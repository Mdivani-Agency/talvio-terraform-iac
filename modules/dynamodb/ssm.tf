locals {
  parameters = {
    for table in aws_dynamodb_table.table : table.name => {
      name        = "dynamodb_${table.name}"
      value       = table.name
      type        = "String"
      prefix      = "dynamodb"
      description = "The name of the DynamoDB table"
      tags        = {}
    }
  }
}

module "ssm" {
  source      = "../ssm"
  environment = var.environment
  region      = var.region
  parameters  = local.parameters
}
