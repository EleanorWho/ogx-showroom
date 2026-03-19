#!/usr/bin/env python3
"""
Generate and persist random passwords for demo services.

This script generates random passwords for all services in the demo
and stores them in ~/.lls_showroom_generated using secrets_util.

The passwords are only generated on first run - subsequent runs will
use the existing passwords unless they are manually deleted.
"""

import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from scripts.secrets_util import get_or_set


def generate_passwords():
    """Generate or retrieve passwords for all services."""

    passwords = {
        'POSTGRES_PASSWORD': None,  # Will use random generator
        'MINIO_ROOT_PASSWORD': None,
        'KEYCLOAK_ADMIN_PASSWORD': None,
        'KEYCLOAK_PASSWORD': None,  # Admin demo user password
        'KEYCLOAK_DEMO_PASSWORD': None,  # Other demo users password (developer, user, etc.)
    }

    print("Generating/retrieving passwords...")

    for key in passwords.keys():
        value = get_or_set(key, check_env=True)
        print(f"  {key}: {'*' * 8} (length: {len(value)})")

    print("\nPasswords stored in ~/.lls_showroom_generated")
    print("To retrieve a password: uv run scripts/secrets_util.py get <KEY>")
    print("  Example: uv run scripts/secrets_util.py get POSTGRES_PASSWORD")


if __name__ == "__main__":
    generate_passwords()
