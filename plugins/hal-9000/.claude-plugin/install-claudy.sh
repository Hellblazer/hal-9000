#!/bin/bash
# Redirect to main install-claudy.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../../../install-claudy.sh" "$@"
