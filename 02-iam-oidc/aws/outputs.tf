output "plan_role_arn" {
  value = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  value = aws_iam_role.apply.arn
}

output "permission_boundary_arn" {
  value = aws_iam_policy.portfolio_boundary.arn
}
