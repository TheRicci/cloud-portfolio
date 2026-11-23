# --- AWS Backup vault and plan ---

resource "aws_backup_vault" "this" {
  name = "${var.name_prefix}-vault"

  tags = {
    project = "backup-lab"
  }
}

resource "aws_backup_plan" "this" {
  name = "${var.name_prefix}-plan"

  rule {
    rule_name         = "daily-never-fires"
    target_vault_name = aws_backup_vault.this.name

    # Schedule set far in the future — backups are on-demand via the script.
    schedule = "cron(0 0 1 1 ? 2099)"

    lifecycle {
      delete_after = 1
    }
  }
}

resource "aws_backup_selection" "this" {
  name         = "${var.name_prefix}-selection"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "project"
    value = "backup-lab"
  }
}
