variable "zone" {
  type        = string
  description = "Route53 zone name (required unless domain is zone apex)"
  default     = null
}

variable "domain" {
  type        = string
  description = "Domain of the website and also name of the S3 bucket"
}

variable "aliases" {
  type        = map(string)
  description = "Map of aliases of the domain to their Route53 zone name"
  default     = {}
}

variable "redirect_target" {
  type        = string
  description = "Redirect all requests to this URL"
  default     = null
}

variable "lambda_edge_arns" {
  type        = map(string)
  description = "The ARNs of Lambda functions to apply to the cloudfront distribution as Lambda@Edge functions"
  default     = {}
}
