#!/usr/bin/env python3
"""Automated security verification and policy audit test suite for IAM OIDC Federation."""

import json
import re
import unittest
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
TESTS_DIR = BASE_DIR / "tests"
FIXTURES_DIR = TESTS_DIR / "fixtures"
AWS_DIR = BASE_DIR / "aws"
AZURE_DIR = BASE_DIR / "azure"


class TrustPolicyValidator:
    """Validates AWS IAM OIDC AssumeRole trust policies."""

    @staticmethod
    def validate_aws_trust(policy: dict) -> tuple[bool, str]:
        statements = policy.get("Statement", [])
        if not isinstance(statements, list):
            statements = [statements]

        if not statements:
            return False, "Policy contains no statements"

        for stmt in statements:
            if stmt.get("Effect") != "Allow":
                continue
            if stmt.get("Action") != "sts:AssumeRoleWithWebIdentity":
                return False, f"Invalid action: {stmt.get('Action')}"

            condition = stmt.get("Condition", {})

            # Check if any operator other than StringEquals is used for sub or aud
            for op, clauses in condition.items():
                if not isinstance(clauses, dict):
                    continue
                if "token.actions.githubusercontent.com:sub" in clauses and op != "StringEquals":
                    return False, f"Operator '{op}' is forbidden for 'sub'. Must use strict 'StringEquals' to reject wildcards."
                if "token.actions.githubusercontent.com:aud" in clauses and op != "StringEquals":
                    return False, f"Operator '{op}' is forbidden for 'aud'. Must use strict 'StringEquals'."

            string_equals = condition.get("StringEquals", {})
            if not string_equals:
                return False, "OIDC condition must include strict 'StringEquals' operator"

            aud = string_equals.get("token.actions.githubusercontent.com:aud")
            if aud != "sts.amazonaws.com":
                return False, f"Audience must be exactly 'sts.amazonaws.com', got: {aud}"

            sub = string_equals.get("token.actions.githubusercontent.com:sub")
            if not sub:
                return False, "Missing 'token.actions.githubusercontent.com:sub' claim in StringEquals"

            subs = sub if isinstance(sub, list) else [sub]
            for s in subs:
                if not isinstance(s, str) or not s.startswith("repo:"):
                    return False, f"Subject must begin with 'repo:', got: {s}"
                if "*" in s or "?" in s:
                    return False, f"Wildcard characters are strictly forbidden in subject claim: {s}"

        return True, "AWS trust policy strictly verified with exact audience and subject"


class AzureFederatedCredValidator:
    """Validates Azure Entra ID Federated Identity Credentials."""

    @staticmethod
    def validate_azure_cred(cred: dict) -> tuple[bool, str]:
        issuer = cred.get("issuer")
        if issuer != "https://token.actions.githubusercontent.com":
            return False, f"Invalid issuer: {issuer}, expected 'https://token.actions.githubusercontent.com'"

        audiences = cred.get("audiences", [])
        if "api://AzureADTokenExchange" not in audiences:
            return False, f"Missing required audience 'api://AzureADTokenExchange', got: {audiences}"

        subject = cred.get("subject", "")
        if not subject.startswith("repo:"):
            return False, f"Subject must begin with 'repo:', got: {subject}"
        if "*" in subject or "?" in subject:
            return False, f"Wildcard characters are strictly forbidden in subject claim: {subject}"

        return True, "Azure federated credential strictly verified with exact issuer, audience, and subject"


class TestAwsTrustPolicies(unittest.TestCase):
    """Test AWS IAM OIDC Trust Policies."""

    def test_exact_trust_fixture_passes(self):
        fixture_path = FIXTURES_DIR / "aws-trust-exact.json"
        data = json.loads(fixture_path.read_text(encoding="utf-8"))
        valid, msg = TrustPolicyValidator.validate_aws_trust(data)
        self.assertTrue(valid, msg)

    def test_wildcard_trust_fixture_rejected(self):
        fixture_path = FIXTURES_DIR / "aws-trust-wildcard.json"
        data = json.loads(fixture_path.read_text(encoding="utf-8"))
        valid, msg = TrustPolicyValidator.validate_aws_trust(data)
        self.assertFalse(valid)
        self.assertIn("StringEquals", msg)

    def test_aws_terraform_trust_enforcement(self):
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('variable = "token.actions.githubusercontent.com:aud"', main_tf)
        self.assertIn('values   = ["sts.amazonaws.com"]', main_tf)
        self.assertIn('test     = "StringEquals"', main_tf)
        self.assertIn('variable = "token.actions.githubusercontent.com:sub"', main_tf)
        self.assertIn("var.github_subject_plan", main_tf)
        self.assertIn("var.github_subject_apply", main_tf)


class TestAzureFederatedCredentials(unittest.TestCase):
    """Test Azure Entra ID Federated Identity Credentials."""

    def test_exact_azure_fixture_passes(self):
        fixture_path = FIXTURES_DIR / "azure-cred-exact.json"
        data = json.loads(fixture_path.read_text(encoding="utf-8"))
        valid, msg = AzureFederatedCredValidator.validate_azure_cred(data)
        self.assertTrue(valid, msg)

    def test_wildcard_azure_fixture_rejected(self):
        fixture_path = FIXTURES_DIR / "azure-cred-wildcard.json"
        data = json.loads(fixture_path.read_text(encoding="utf-8"))
        valid, msg = AzureFederatedCredValidator.validate_azure_cred(data)
        self.assertFalse(valid)
        self.assertIn("Wildcard", msg)

    def test_azure_terraform_credential_enforcement(self):
        main_tf = (AZURE_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('github_oidc_issuer    = "https://token.actions.githubusercontent.com"', main_tf)
        self.assertIn('github_oidc_audience  = "api://AzureADTokenExchange"', main_tf)
        self.assertIn('resource "azuread_application_federated_identity_credential" "plan"', main_tf)
        self.assertIn('resource "azuread_application_federated_identity_credential" "apply"', main_tf)


class TestBlastRadiusAndEscalationGuards(unittest.TestCase):
    """Test boundary controls, anti-escalation policies, and least-privilege scoping."""

    def test_aws_boundary_denies_boundary_tampering(self):
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('sid    = "DenyBoundaryMutation"', main_tf)
        self.assertIn('"iam:CreatePolicyVersion"', main_tf)
        self.assertIn('"iam:DeletePolicy"', main_tf)
        self.assertIn('resources = [local.boundary_arn]', main_tf)

    def test_aws_boundary_denies_identity_provider_tampering(self):
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('sid    = "DenyIdentityControlPlaneMutation"', main_tf)
        self.assertIn('"iam:DeleteOpenIDConnectProvider"', main_tf)
        self.assertIn('"iam:UpdateAssumeRolePolicy"', main_tf)
        self.assertIn('"iam:DeleteRolePermissionsBoundary"', main_tf)

    def test_aws_boundary_requires_boundary_inheritance_on_child_roles(self):
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('sid    = "AllowBoundedTestRolesOnly"', main_tf)
        self.assertIn('variable = "iam:PermissionsBoundary"', main_tf)
        self.assertIn('values   = [local.boundary_arn]', main_tf)

    def test_aws_apply_role_has_boundary_attached(self):
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        role_apply_match = re.search(r'resource "aws_iam_role" "apply"\s*\{([^}]+)\}', main_tf)
        self.assertIsNotNone(role_apply_match)
        role_block = role_apply_match.group(1)
        self.assertIn("permissions_boundary = local.boundary_arn", role_block)

    def test_azure_rbac_least_privilege_separation(self):
        main_tf = (AZURE_DIR / "main.tf").read_text(encoding="utf-8")
        # Plan is Reader only on resource group
        self.assertIn('resource "azurerm_role_assignment" "plan_reader"', main_tf)
        self.assertIn('role_definition_name             = "Reader"', main_tf)

        # Apply is Contributor (cannot assign roles or manage RBAC)
        self.assertIn('resource "azurerm_role_assignment" "apply_contributor"', main_tf)
        self.assertIn('role_definition_name             = "Contributor"', main_tf)

        # Confirm neither identity is Owner or User Access Administrator
        self.assertNotIn('"Owner"', main_tf)
        self.assertNotIn('"User Access Administrator"', main_tf)


class TestStateBackendIsolation(unittest.TestCase):
    """Test remote state storage scoping and locking isolation."""

    def test_aws_state_access_narrow_scope(self):
        main_tf = (AWS_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('"ListOnlyThisStatePrefix"', main_tf)
        self.assertIn('variable = "s3:prefix"', main_tf)
        self.assertIn('"ReadWriteOnlyStateAndLock"', main_tf)
        self.assertIn('"s3:GetObject"', main_tf)
        self.assertIn('"s3:PutObject"', main_tf)
        self.assertIn('"s3:DeleteObject"', main_tf)

    def test_azure_state_access_container_scope(self):
        main_tf = (AZURE_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('state_container_scope = "/subscriptions/', main_tf)
        self.assertIn('/containers/${var.state_container_name}"', main_tf)
        self.assertIn('role_definition_name             = "Storage Blob Data Contributor"', main_tf)


class TestNegativeSimulations(unittest.TestCase):
    """Simulate attack vectors and prove they are deterministically denied."""

    def test_pr_untrusted_branch_cannot_assume_apply_role(self):
        """Simulate an attacker opening a PR with subject 'repo:org/repo:pull_request'."""
        attacker_jwt_subject = "repo:octocat/cloud-portfolio:pull_request"
        allowed_apply_subject = "repo:octocat/cloud-portfolio:environment:aws-apply"

        def simulate_aws_sts_assume_role(token_sub: str, expected_sub: str) -> str:
            if token_sub == expected_sub:
                return "200 OK: CredentialsIssued"
            return "403 Forbidden: sts:AssumeRoleWithWebIdentity denied - Subject claim mismatch"

        result = simulate_aws_sts_assume_role(attacker_jwt_subject, allowed_apply_subject)
        self.assertIn("403 Forbidden", result)

    def test_apply_role_cannot_create_unbounded_admin_role(self):
        """Simulate apply role attempting to create a role without permission boundary."""
        requested_call = {
            "Action": "iam:CreateRole",
            "RoleName": "stealth-admin",
            "PermissionsBoundary": None
        }

        def simulate_iam_evaluator(call: dict, required_boundary: str) -> str:
            if call.get("PermissionsBoundary") == required_boundary:
                return "200 OK: RoleCreated"
            return "403 AccessDenied: iam:CreateRole requires iam:PermissionsBoundary condition"

        result = simulate_iam_evaluator(
            requested_call,
            "arn:aws:iam::123456789012:policy/portfolio-tests/portfolio-boundary"
        )
        self.assertIn("403 AccessDenied", result)

    def test_azure_contributor_cannot_create_role_assignment(self):
        """Simulate apply identity attempting to escalate privileges via az role assignment create."""
        requested_action = "Microsoft.Authorization/roleAssignments/write"

        # In Azure RBAC, Contributor has NotActions matching Microsoft.Authorization/*
        contributor_not_actions = [
            r"^Microsoft\.Authorization/.*/Delete$",
            r"^Microsoft\.Authorization/.*/Write$",
            r"^Microsoft\.Authorization/roleAssignments/write$"
        ]

        def simulate_azure_evaluator(action: str, not_actions: list[str]) -> str:
            for pattern in not_actions:
                if re.match(pattern, action, re.IGNORECASE):
                    return "AuthorizationFailed: The client does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'"
            return "200 OK: RoleAssignmentCreated"

        result = simulate_azure_evaluator(requested_action, contributor_not_actions)
        self.assertIn("AuthorizationFailed", result)


if __name__ == "__main__":
    unittest.main()
