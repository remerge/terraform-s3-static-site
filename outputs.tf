output "s3_bucket_arn" {
  description = "ARN of the created bucket"
  value       = aws_s3_bucket.main.arn
}

output "cloudfront_distribution_arn" {
  description = "ARN of the created cloudfront distribution"
  value       = aws_cloudfront_distribution.main.arn
}
