variable "region" {
  default = "us-east-1"
}

variable "class_no" {
  default = "ie3a26v2" 
}

variable "db_password" {
  type      = string
  sensitive = true
}