#!/usr/bin/env python3
"""
Secrets utility for managing persistent secrets across deployments.

Usage as module:
    from scripts.secrets_util import get_or_set
    secret = get_or_set('KEYCLOAK_CLIENT_SECRET')

Usage as CLI:
    python scripts/secrets_util.py get_or_set KEYCLOAK_CLIENT_SECRET
    python scripts/secrets_util.py get KEYCLOAK_CLIENT_SECRET
"""

import os
import sys
import secrets
import string
import yaml
from pathlib import Path
from typing import Optional, Dict, Any


DEFAULT_SECRETS_FILE = os.path.expanduser("~/.lls_showroom_generated")
DEFAULT_SECRET_LENGTH = 12


def _generate_random_secret(length: int = DEFAULT_SECRET_LENGTH) -> str:
    """Generate a random string."""
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))


def _load_secrets(secrets_file: str = DEFAULT_SECRETS_FILE) -> Dict[str, Any]:
    """Load secrets from YAML file."""
    path = Path(secrets_file)

    if not path.exists():
        return {}

    try:
        with open(path, 'r') as f:
            data = yaml.safe_load(f) or {}
            return data.get('secrets', {})
    except Exception as e:
        print(f"Warning: Failed to load secrets from {secrets_file}: {e}", file=sys.stderr)
        return {}


def _save_secrets(secrets_data: Dict[str, Any], secrets_file: str = DEFAULT_SECRETS_FILE) -> None:
    """Save secrets to YAML file with secure permissions."""
    path = Path(secrets_file)

    # Create directory if it doesn't exist
    path.parent.mkdir(parents=True, exist_ok=True)

    # Write data
    data = {'secrets': secrets_data}
    with open(path, 'w') as f:
        yaml.safe_dump(data, f, default_flow_style=False, sort_keys=True)

    # Set secure permissions (owner read/write only)
    path.chmod(0o600)


def get_or_set(
    key: str,
    default: Optional[str] = None,
    generator: Optional[callable] = None,
    secrets_file: str = DEFAULT_SECRETS_FILE,
    check_env: bool = True
) -> str:
    """
    Get a secret value by key, or set it if not present.

    Lookup order:
    1. Secrets file (~/.lls_showroom_generated)
    2. Environment variable (if check_env=True)
    3. Generate new value (default, generator, or random)

    Args:
        key: Secret key name
        default: Default value to use if not present (if provided, generator is ignored)
        generator: Callable to generate the secret if not present (default: random string)
        secrets_file: Path to secrets file (default: ~/.lls_showroom_generated)
        check_env: Whether to check environment variable before generating (default: True)

    Returns:
        The secret value
    """
    secrets_data = _load_secrets(secrets_file)

    if key in secrets_data:
        return secrets_data[key]

    # Check environment variable if enabled
    if check_env:
        env_value = os.environ.get(key)
        if env_value:
            # Save it to secrets file for persistence
            secrets_data[key] = env_value
            _save_secrets(secrets_data, secrets_file)
            return env_value

    # Generate new secret
    if default is not None:
        value = default
    elif generator is not None:
        value = generator()
    else:
        value = _generate_random_secret()

    # Save it
    secrets_data[key] = value
    _save_secrets(secrets_data, secrets_file)

    return value


def get(key: str, default: Optional[str] = None, secrets_file: str = DEFAULT_SECRETS_FILE) -> Optional[str]:
    """
    Get a secret value by key without setting it.

    Args:
        key: Secret key name
        default: Default value to return if key not found
        secrets_file: Path to secrets file (default: ~/.lls_showroom_generated)

    Returns:
        The secret value or default if not found
    """
    secrets_data = _load_secrets(secrets_file)
    return secrets_data.get(key, default)


def set_secret(key: str, value: str, secrets_file: str = DEFAULT_SECRETS_FILE) -> None:
    """
    Set a secret value.

    Args:
        key: Secret key name
        value: Secret value
        secrets_file: Path to secrets file (default: ~/.lls_showroom_generated)
    """
    secrets_data = _load_secrets(secrets_file)
    secrets_data[key] = value
    _save_secrets(secrets_data, secrets_file)


def delete(key: str, secrets_file: str = DEFAULT_SECRETS_FILE) -> bool:
    """
    Delete a secret.

    Args:
        key: Secret key name
        secrets_file: Path to secrets file (default: ~/.lls_showroom_generated)

    Returns:
        True if key was deleted, False if it didn't exist
    """
    secrets_data = _load_secrets(secrets_file)

    if key not in secrets_data:
        return False

    del secrets_data[key]
    _save_secrets(secrets_data, secrets_file)
    return True


def list_keys(secrets_file: str = DEFAULT_SECRETS_FILE) -> list:
    """
    List all secret keys.

    Args:
        secrets_file: Path to secrets file (default: ~/.lls_showroom_generated)

    Returns:
        List of secret keys
    """
    secrets_data = _load_secrets(secrets_file)
    return sorted(secrets_data.keys())


def main():
    """CLI interface."""
    if len(sys.argv) < 2:
        print("Usage: secrets_util.py <command> [args...]", file=sys.stderr)
        print("Commands:", file=sys.stderr)
        print("  get_or_set <key>          Get or set a secret", file=sys.stderr)
        print("  get <key> [default]       Get a secret", file=sys.stderr)
        print("  set <key> <value>         Set a secret", file=sys.stderr)
        print("  delete <key>              Delete a secret", file=sys.stderr)
        print("  list                      List all secret keys", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]

    try:
        if command == "get_or_set":
            if len(sys.argv) < 3:
                print("Usage: secrets_util.py get_or_set <key>", file=sys.stderr)
                sys.exit(1)
            key = sys.argv[2]
            value = get_or_set(key)
            print(value)

        elif command == "get":
            if len(sys.argv) < 3:
                print("Usage: secrets_util.py get <key> [default]", file=sys.stderr)
                sys.exit(1)
            key = sys.argv[2]
            default = sys.argv[3] if len(sys.argv) > 3 else None
            value = get(key, default)
            if value is None:
                print(f"Key '{key}' not found", file=sys.stderr)
                sys.exit(1)
            print(value)

        elif command == "set":
            if len(sys.argv) < 4:
                print("Usage: secrets_util.py set <key> <value>", file=sys.stderr)
                sys.exit(1)
            key = sys.argv[2]
            value = sys.argv[3]
            set_secret(key, value)
            print(f"Set '{key}' successfully")

        elif command == "delete":
            if len(sys.argv) < 3:
                print("Usage: secrets_util.py delete <key>", file=sys.stderr)
                sys.exit(1)
            key = sys.argv[2]
            if delete(key):
                print(f"Deleted '{key}' successfully")
            else:
                print(f"Key '{key}' not found", file=sys.stderr)
                sys.exit(1)

        elif command == "list":
            keys = list_keys()
            if keys:
                for key in keys:
                    print(key)
            else:
                print("No secrets stored", file=sys.stderr)

        else:
            print(f"Unknown command: {command}", file=sys.stderr)
            sys.exit(1)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
