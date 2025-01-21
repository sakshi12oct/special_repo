variable "region" {
  type = string
  default = "ap-southeast-1"
}

variable "s3bucket_name" {
  type = string
  default = "ih-pro-remotestate-3"
}

variable "dynamo_db_name" {
  type = string
  default = "ih-pro-db_name-3"
}