variable "zone" {
  type        = string
  description = "Route53 Zone ID of the FQDN"
  default     = null
}

variable "fqdn" {
  type        = string
  description = "The FQDN of the website and also name of the S3 bucket"
}

variable "target" {
  type        = string
  description = "The URL to redirect to"
}

variable "aliases" {
  type        = list(string)
  description = "List of aliases to the FQDN"
  default     = []
}
