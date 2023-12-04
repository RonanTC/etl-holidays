variable "rds_oltp_usr" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "rds_oltp_pass" {
  type      = string
  sensitive = true
  nullable  = false
}