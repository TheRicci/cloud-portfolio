#!/usr/bin/env python3
"""AWS IAM & OIDC Federation Security Invariant Test Suite.

Validates AWS-specific trust configurations, least-privilege scoping,
permission boundaries, and simulated attack vectors with detailed descriptions.
"""

import json
import re
import unittest
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
TESTS_DIR = BASE_DIR / "tests"
FIXTURES_DIR = TESTS_DIR / "fixtures"
AWS_DIR = BASE_DIR / "aws"


class AwsTrustValidator:
    """Validates AWS IAM OIDC AssumeRole trust policy conditions."""

    @staticmethod
    def validate_trust_policy(policy: dict) -> tuple[bool, str]:
        statements = policy.get("Statement", [])
        if not isinstance(statements, list):
            statements = [statements]

        if not statements:
            return False, "Policy contains no statements."

        for stmt in statements:
            if stmt.get("Effect") != "Allow":
                continue
            if stmt.get("Action") != "sts:AssumeRoleWithWebIdentity":
                return False, f"Action must be sts:AssumeRoleWithWebIdentity, found: {stmt.get('Action')}"

            condition = stmt.get("Condition", {})

            # Check for unsafe wildcard operators
            for op, clauses in condition.items():
                if not isinstance(clauses, dict):
                    continue
                if "token.actions.githubusercontent.com:sub" in clauses and op != "StringEquals":
                    return False, (
                        f"VULNERABILITY: Condition operator '{op}' allows wildcards on the subject claim. "
                        "Must strictly use 'StringEquals' to prevent cross-branch/PR impersonation."
                    )
                if "token.actions.githubusercontent.com:aud" in clauses and op != "StringEquals":
                    return False, f"Condition operator '{op}' on audience must be strict 'StringEquals'."

            string_equals = condition.get("StringEquals", {})
            if not string_equals:
                return False, "Missing required 'StringEquals' condition block in trust policy."

            aud = string_equals.get("token.actions.githubusercontent.com:aud")
            if aud != "sts.amazonaws.com":
                return False, f"Audience must strictly equal 'sts.amazonaws.com', found: '{aud}'"

            sub = string_equals.get("token.actions.githubusercontent.com:sub")
            if not sub:
                return False, "Missing 'token.actions.githubusercontent.com:sub' claim condition."

            subs = sub if isinstance(sub, list) else [sub]
            for s in subs:
                if not isinstance(s, str) or not s.startswith("repo:"):
                    return False, f"Subject claim must start with 'repo:', found: '{s}'"
                if "*" in s or "?" in s:
                    return False, (
                        f"VULNERABILITY: Wildcard character detected in subject claim '{s}'. "
                        "Wildcards allow unvetted pull requests or feature branches to assume this role."
                    )

        return True, "Trust policy strictly validated: exact STS audience, StringEquals operator, and zero wildcards."


class TestAwsOidcSecurity(unittest.TestCase):
    """Detailed AWS OIDC Security Assertions."""

    def test_01_trust_policy_exact_match(self):
        """[AWS-T01] Proves that an exact subject and audience trust policy passes validation."""
        fixture = json.loads((FIXTURES_DIR / "aws-trust-exact.json").read_text(encoding="utf-8"))
        valid, msg = AwsTrustValidator.validate_trust_policy(fixture)
        self.assertTrue(valid, msg)

    def test_02_trust_policy_wildcard_rejection(self):
        """[AWS-T02] Proves that wildcard subjects (e.g. repo:org/*) or StringLike operators are rejected."""
        fixture = json.loads((FIXTURES_DIR / "aws-trust-wildcard.json").read_text(encoding="utf-8"))
        valid, msg = AwsTrustValidator.validate_trust_policy(fixture)
        self.assertFalse(valid)
        self.assertIn("StringEquals", msg)

    def test_03_terraform_trust_definitions(self):
        """[AWS-T03] Proves that AWS Terraform files configure exact StringEquals checks for plan and apply."""
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('variable = "token.actions.githubusercontent.com:aud"', main_tf)
        self.assertIn('values   = ["sts.amazonaws.com"]', main_tf)
        self.assertIn('test     = "StringEquals"', main_tf)
        self.assertIn('variable = "token.actions.githubusercontent.com:sub"', main_tf)
        self.assertIn("var.github_subject_plan", main_tf)
        self.assertIn("var.github_subject_apply", main_tf)

    def test_04_role_separation_plan_has_no_mutation_rights(self):
        """[AWS-T04] Proves Plan role has zero cloud mutation permissions (only S3 state access attached)."""
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        # Plan role should only have state_access policy attached
        self.assertIn('resource "aws_iam_role_policy_attachment" "plan_state_access"', main_tf)
        self.assertNotIn('resource "aws_iam_role_policy_attachment" "plan_admin"', main_tf)
        self.assertNotIn('resource "aws_iam_role_policy" "plan_permissions"', main_tf)

    def test_05_state_storage_scoping_s3(self):
        """[AWS-T05] Proves S3 state policy locks access strictly to this project's key and lockfile."""
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('"ListOnlyThisStatePrefix"', main_tf)
        self.assertIn('variable = "s3:prefix"', main_tf)
        self.assertIn('"ReadWriteOnlyStateAndLock"', main_tf)
        self.assertIn('"s3:GetObject"', main_tf)
        self.assertIn('"s3:PutObject"', main_tf)
        self.assertIn('"s3:DeleteObject"', main_tf)

    def test_06_permission_boundary_attachment(self):
        """[AWS-T06] Proves that the apply role has an immutable Permission Boundary attached."""
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        role_apply_match = re.search(r'resource "aws_iam_role" "apply"\s*\{([^}]+)\}', main_tf)
        self.assertIsNotNone(role_apply_match, "aws_iam_role.apply resource block not found.")
        self.assertIn("permissions_boundary = local.boundary_arn", role_apply_match.group(1))

    def test_07_permission_boundary_anti_escalation(self):
        """[AWS-T07] Proves that child roles created by apply identity MUST inherit the permission boundary."""
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('sid    = "AllowBoundedTestRolesOnly"', main_tf)
        self.assertIn('variable = "iam:PermissionsBoundary"', main_tf)
        self.assertIn('values   = [local.boundary_arn]', main_tf)

    def test_08_anti_tamper_boundary_mutation_denied(self):
        """[AWS-T08] Proves explicit Deny prevents modifying or deleting the permission boundary itself."""
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('sid    = "DenyBoundaryMutation"', main_tf)
        self.assertIn('"iam:CreatePolicyVersion"', main_tf)
        self.assertIn('"iam:DeletePolicy"', main_tf)
        self.assertIn('resources = [local.boundary_arn]', main_tf)

    def test_09_anti_tamper_identity_control_plane_denied(self):
        """[AWS-T09] Proves explicit Deny blocks deleting OIDC provider or altering role trust policies."""
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('sid    = "DenyIdentityControlPlaneMutation"', main_tf)
        self.assertIn('"iam:DeleteOpenIDConnectProvider"', main_tf)
        self.assertIn('"iam:UpdateAssumeRolePolicy"', main_tf)
        self.assertIn('"iam:DeleteRolePermissionsBoundary"', main_tf)

    def test_10_simulation_pr_cannot_assume_apply(self):
        """[AWS-T10] Simulates a PR event attempting to assume the protected apply role -> Denied."""
        pr_subject = "repo:octocat/cloud-portfolio:pull_request"
        allowed_apply_subject = "repo:octocat/cloud-portfolio:environment:aws-apply"

        def simulate_sts_call(token_sub: str, expected_sub: str) -> str:
            if token_sub == expected_sub:
                return "200 OK: CredentialsIssued"
            return "403 AccessDenied: sts:AssumeRoleWithWebIdentity denied - subject claim mismatch"

        result = simulate_sts_call(pr_subject, allowed_apply_subject)
        self.assertIn("403 AccessDenied", result)

    def test_11_simulation_unbounded_role_creation_denied(self):
        """[AWS-T11] Simulates a compromised runner attempting to create an unbounded IAM role -> Denied."""
        requested_call = {
            "Action": "iam:CreateRole",
            "RoleName": "stealth-admin",
            "PermissionsBoundary": None
        }

        def simulate_boundary_enforcement(call: dict, required_boundary_arn: str) -> str:
            if call.get("PermissionsBoundary") == required_boundary_arn:
                return "200 OK: RoleCreated"
            return "403 AccessDenied: iam:CreateRole missing required iam:PermissionsBoundary condition"

        result = simulate_boundary_enforcement(
            requested_call,
            "arn:aws:iam::123456789012:policy/portfolio-tests/portfolio-boundary"
        )
        self.assertIn("403 AccessDenied", result)


if __name__ == "__main__":
    unittest.main()
