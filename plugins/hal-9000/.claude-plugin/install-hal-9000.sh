#!/bin/bash
# Redirect to main install-hal-9000.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../../../install-hal-9000.sh" "$@"
