#!/usr/bin/env python3
"""Reject unsafe GitHub Actions OIDC trust-policy subjects."""

import json
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


if len(sys.argv) != 2:
    print(f"usage: {Path(sys.argv[0]).name} <assume-role-policy.json>", file=sys.stderr)
    raise SystemExit(64)

policy = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
statements = policy.get("Statement", [])
if not isinstance(statements, list):
    statements = [statements]

for statement in statements:
    condition = statement.get("Condition", {})
    for operator, clauses in condition.items():
        if not isinstance(clauses, dict):
            continue
        subject = clauses.get("token.actions.githubusercontent.com:sub")
        if subject is None:
            continue
        subjects = subject if isinstance(subject, list) else [subject]
        for value in subjects:
            if operator != "StringEquals":
                fail("OIDC subject must use StringEquals, not a wildcard-capable operator.")
            if not isinstance(value, str) or not value.startswith("repo:"):
                fail("OIDC subject must be a GitHub repository subject.")
            if "*" in value or "?" in value:
                fail("OIDC subject must not contain wildcard characters.")

    audience = condition.get("StringEquals", {}).get(
        "token.actions.githubusercontent.com:aud"
    )
    if audience != "sts.amazonaws.com":
        fail("OIDC trust must require the exact sts.amazonaws.com audience.")

    subject = condition.get("StringEquals", {}).get(
        "token.actions.githubusercontent.com:sub"
    )
    if subject is not None:
        print("AWS trust policy has an exact audience and subject.")
        raise SystemExit(0)

fail("OIDC trust policy has no exact GitHub subject condition.")
