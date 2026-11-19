#!/usr/bin/env python3
"""Render the Alertmanager template using environment variables or safe defaults for local runs."""
from __future__ import annotations

import os
import pathlib
import string
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])

defaults = {
    "SMTP_SMARTHOST": "localhost:25",
    "SMTP_FROM": "alertmanager@example.com",
    "SMTP_USERNAME": "default",
    "SMTP_PASSWORD": "default",
    "ALERT_EMAIL": "alerts@example.com",
}

env = {**defaults, **{k: v for k, v in os.environ.items() if v}}

target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(string.Template(source.read_text()).safe_substitute(env), encoding="utf-8")
target.chmod(0o600)
print(f"Rendered Alertmanager config to {target}")
