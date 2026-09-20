resource "aws_dynamodb_table" "table" {
  for_each = var.dynamo_db_tables

  name                        = each.key
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = each.value.hash_key
  range_key                   = each.value.range_key
  stream_enabled              = each.value.stream_enabled
  deletion_protection_enabled = each.value.deletion_protection_enabled
  stream_view_type            = each.value.stream_enabled ? "NEW_AND_OLD_IMAGES" : null
  table_class                 = "STANDARD"

  attribute {
    name = each.value.hash_key
    type = "S"
  }

  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.key
      type = attribute.value
    }
  }

  point_in_time_recovery {
    enabled = each.value.point_in_time_recovery
  }

  dynamic "global_secondary_index" {
    for_each = each.value.global_secondary_indexes
    content {
      name            = global_secondary_index.key
      projection_type = coalesce(global_secondary_index.value.projection_type, "ALL")
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
    }
  }

  dynamic "ttl" {
    for_each = each.value.ttl == null ? [] : [each.value.ttl]
    content {
      attribute_name = ttl.value.attribute_name
      enabled        = ttl.value.enabled
    }
  }

  tags = {
    "user:Application" = "talv-backend"
    "user:Stack"       = var.environment
  }
}
