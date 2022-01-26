variable "zone_id" {
  type        = string
  description = "Route53 Zone ID of the domain (required unless domain is zone apex)"
  default     = null
}

variable "domain" {
  type        = string
  description = "Domain of the website and also name of the S3 bucket"
}

variable "aliases" {
  type        = list(string)
  description = "List of aliases to the domain"
  default     = []
}

variable "redirect_target" {
  type        = string
  description = "Redirect all requests to this URL"
}

variable "lambda_edge_arns" {
  type        = map(string)
  description = "The ARNs of Lambda functions to apply to the cloudfront distribution as Lambda@Edge functions"
  default     = {}
}
