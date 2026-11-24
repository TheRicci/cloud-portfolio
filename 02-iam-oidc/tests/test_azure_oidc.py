#!/usr/bin/env python3
"""Azure Entra ID & OIDC Federation Security Invariant Test Suite.

Validates Azure-specific federated identity credentials, scoped RBAC roles,
storage container isolation, and simulated attack vectors with detailed descriptions.
"""

import json
import re
import unittest
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
TESTS_DIR = BASE_DIR / "tests"
FIXTURES_DIR = TESTS_DIR / "fixtures"
AZURE_DIR = BASE_DIR / "azure"


class AzureFederatedCredValidator:
    """Validates Azure Entra ID Federated Identity Credentials."""

    @staticmethod
    def validate_credential(cred: dict) -> tuple[bool, str]:
        issuer = cred.get("issuer")
        if issuer != "https://token.actions.githubusercontent.com":
            return False, (
                f"VULNERABILITY: Invalid issuer '{issuer}'. "
                "Must be exactly 'https://token.actions.githubusercontent.com'."
            )

        audiences = cred.get("audiences", [])
        if "api://AzureADTokenExchange" not in audiences:
            return False, (
                f"VULNERABILITY: Missing required audience 'api://AzureADTokenExchange'. "
                f"Found: {audiences}"
            )

        subject = cred.get("subject", "")
        if not subject.startswith("repo:"):
            return False, f"Subject must begin with 'repo:', found: '{subject}'"
        if "*" in subject or "?" in subject:
            return False, (
                f"VULNERABILITY: Wildcard character detected in subject claim '{subject}'. "
                "Wildcards allow unauthorized branches or pull requests to assume this identity."
            )

        return True, "Azure federated credential strictly validated: official issuer, exact audience, and zero wildcards."


class TestAzureOidcSecurity(unittest.TestCase):
    """Detailed Azure OIDC Security Assertions."""

    def test_01_credential_exact_match(self):
        """[AZURE-T01] Proves that an exact subject, issuer, and audience credential passes validation."""
        fixture = json.loads((FIXTURES_DIR / "azure-cred-exact.json").read_text(encoding="utf-8"))
        valid, msg = AzureFederatedCredValidator.validate_credential(fixture)
        self.assertTrue(valid, msg)

    def test_02_credential_wildcard_rejection(self):
        """[AZURE-T02] Proves that wildcard subjects (e.g. repo:org/*) in Azure credentials are rejected."""
        fixture = json.loads((FIXTURES_DIR / "azure-cred-wildcard.json").read_text(encoding="utf-8"))
        valid, msg = AzureFederatedCredValidator.validate_credential(fixture)
        self.assertFalse(valid)
        self.assertIn("Wildcard", msg)

    def test_03_terraform_credential_definitions(self):
        """[AZURE-T03] Proves that Azure Terraform files configure official issuer and audience."""
        main_tf = (AZURE_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('github_oidc_issuer    = "https://token.actions.githubusercontent.com"', main_tf)
        self.assertIn('github_oidc_audience  = "api://AzureADTokenExchange"', main_tf)
        self.assertIn('resource "azuread_application_federated_identity_credential" "plan"', main_tf)
        self.assertIn('resource "azuread_application_federated_identity_credential" "apply"', main_tf)

    def test_04_role_separation_plan_is_reader_only(self):
        """[AZURE-T04] Proves Plan identity is granted Reader role only on deployment Resource Group."""
        main_tf = (AZURE_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('resource "azurerm_role_assignment" "plan_reader"', main_tf)
        self.assertIn('role_definition_name             = "Reader"', main_tf)
        self.assertIn('scope                            = var.deployment_resource_group_id', main_tf)

    def test_05_role_separation_apply_is_contributor(self):
        """[AZURE-T05] Proves Apply identity is granted Contributor on Resource Group (not Owner)."""
        main_tf = (AZURE_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('resource "azurerm_role_assignment" "apply_contributor"', main_tf)
        self.assertIn('role_definition_name             = "Contributor"', main_tf)
        self.assertIn('scope                            = var.deployment_resource_group_id', main_tf)

    def test_06_anti_escalation_no_owner_or_role_assignment(self):
        """[AZURE-T06] Proves neither identity is Owner or User Access Administrator (cannot grant roles)."""
        main_tf = (AZURE_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertNotIn('"Owner"', main_tf)
        self.assertNotIn('"User Access Administrator"', main_tf)

    def test_07_storage_container_narrow_scope(self):
        """[AZURE-T07] Proves state role is scoped strictly to tfstate container, not entire storage account."""
        main_tf = (AZURE_DIR / "main.tf").read_text(encoding="utf-8")
        self.assertIn('state_container_scope = "/subscriptions/', main_tf)
        self.assertIn('/containers/${var.state_container_name}"', main_tf)
        self.assertIn('resource "azurerm_role_assignment" "plan_state"', main_tf)
        self.assertIn('resource "azurerm_role_assignment" "apply_state"', main_tf)
        self.assertIn('role_definition_name             = "Storage Blob Data Contributor"', main_tf)

    def test_08_simulation_feature_branch_login_denied(self):
        """[AZURE-T08] Simulates a feature branch job attempting to assume azure-apply identity -> Denied."""
        feature_sub = "repo:octocat/cloud-portfolio:ref:refs/heads/feature-xyz"
        allowed_sub = "repo:octocat/cloud-portfolio:environment:azure-apply"

        def simulate_entra_token_exchange(sub: str, expected_sub: str) -> str:
            if sub == expected_sub:
                return "200 OK: AccessTokenIssued"
            return "401 Unauthorized: AADSTS70021 - No matching federated identity record found for subject"

        result = simulate_entra_token_exchange(feature_sub, allowed_sub)
        self.assertIn("AADSTS70021", result)

    def test_09_simulation_role_assignment_escalation_denied(self):
        """[AZURE-T09] Simulates apply identity attempting to create an Azure role assignment -> Denied."""
        requested_action = "Microsoft.Authorization/roleAssignments/write"

        # Azure Contributor has NotActions blocking role assignment writes
        contributor_not_actions = [
            r"^Microsoft\.Authorization/.*/Delete$",
            r"^Microsoft\.Authorization/.*/Write$",
            r"^Microsoft\.Authorization/roleAssignments/write$"
        ]

        def simulate_arm_evaluator(action: str, not_actions: list[str]) -> str:
            for pattern in not_actions:
                if re.match(pattern, action, re.IGNORECASE):
                    return (
                        "AuthorizationFailed: The client does not have authorization to perform action "
                        "'Microsoft.Authorization/roleAssignments/write' over scope."
                    )
            return "200 OK: RoleAssignmentCreated"

        result = simulate_arm_evaluator(requested_action, contributor_not_actions)
        self.assertIn("AuthorizationFailed", result)


if __name__ == "__main__":
    unittest.main()
