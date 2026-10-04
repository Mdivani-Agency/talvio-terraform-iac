resource "aws_ses_template" "templates" {
  for_each = var.ses_templates
  name     = each.value["name"]
  subject  = each.value["subject"]
  html     = file("${path.root}/variables/templates/${each.value["body_file"]}")
}
