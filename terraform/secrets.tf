resource "aws_secretsmanager_secret" "oltp_admin_user" {
  name = "oltp_admin_user"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "oltp_admin_user" {
  secret_id     = aws_secretsmanager_secret.oltp_admin_user.id
  secret_string = var.rds_oltp_admin_usr
}

resource "aws_secretsmanager_secret" "oltp_admin_pass" {
  name = "oltp_admin_pass"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "oltp_admin_pass" {
  secret_id     = aws_secretsmanager_secret.oltp_admin_pass.id
  secret_string = var.rds_oltp_admin_pass
}
