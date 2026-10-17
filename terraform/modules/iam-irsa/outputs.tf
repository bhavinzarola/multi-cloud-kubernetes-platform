output "role_arn" {
  description = "ARN of the created IRSA role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  value = aws_iam_role.this.name
}
