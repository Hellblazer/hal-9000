#!/bin/bash
# Entrypoint for hal-9000 Ubuntu test container
# Switches to testuser and runs commands

set -e

echo "=== HAL-9000 Full Test Environment (Ubuntu) ==="

# Check if Docker socket is mounted (for container tests)
if [ -S /var/run/docker.sock ]; then
    echo "Docker socket available"
    chmod 666 /var/run/docker.sock 2>/dev/null || true
else
    echo "Note: Docker socket not mounted (container tests will be skipped)"
    echo "  Mount with: -v /var/run/docker.sock:/var/run/docker.sock"
fi

# Switch to test user
if [ "$1" = "/bin/bash" ] || [ "$1" = "bash" ]; then
    echo ""
    echo "Interactive mode. Test user: testuser"
    echo "hal-9000 source: /hal-9000-src"
    echo ""
    echo "Quick start:"
    echo "  cd /hal-9000-src && ./install.sh"
    echo ""
    echo "Run full tests:"
    echo "  /hal-9000/test/run-full-tests.sh"
    echo ""
    exec su - testuser
else
    # Run command as testuser
    exec su - testuser -c "$*"
fi
