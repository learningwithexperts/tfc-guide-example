variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "dns_zone" {
  type    = string
  default = "learningwithexperts.com"
}

variable "db_table_name" {
  type    = string
  default = "terraform-learn"
}

variable "db_read_capacity" {
  type    = number
  default = 1
}

variable "db_write_capacity" {
  type    = number
  default = 1
}