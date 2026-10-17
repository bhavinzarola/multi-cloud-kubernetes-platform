variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "eks-demo-app"
}

variable "image_tag_mutability" {
  type    = string
  default = "IMMUTABLE"
}

variable "scan_on_push" {
  type    = bool
  default = true
}

variable "max_image_count" {
  description = "Number of most-recent images to retain via lifecycle policy"
  type        = number
  default     = 10
}

variable "cross_account_read_principals" {
  description = "Optional list of AWS account principal ARNs granted pull access (multi-account extension)"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
