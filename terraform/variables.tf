variable "region" {
  type = string
  default = "eu-west-2"
}

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

variable "rds_oltp_admin_usr" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "rds_oltp_admin_pass" {
  type      = string
  sensitive = true
  nullable  = false
}