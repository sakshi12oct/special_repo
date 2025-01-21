variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "arn_administrators" {
  description = "arn of the user, for example arn:aws:iam::111122223333:user/my-user. Run in CLI aws iam get-user or aws iam get-group"
  type        = set(string)
  default = [
    
    "arn:aws:iam::438465169137:user/Sakshi"
  ]

}
