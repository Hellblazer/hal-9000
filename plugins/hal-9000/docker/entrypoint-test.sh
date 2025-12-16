#!/bin/bash
# Entrypoint for hal-9000 DinD test container
# Starts Docker daemon, waits for it, then executes command

set -e

echo "=== HAL-9000 Test Environment ==="
echo "Starting Docker daemon..."

# Start Docker daemon in background
dockerd-entrypoint.sh dockerd &
DOCKER_PID=$!

# Wait for Docker to be ready
echo "Waiting for Docker daemon..."
TRIES=0
MAX_TRIES=30
while ! docker info >/dev/null 2>&1; do
    TRIES=$((TRIES + 1))
    if [ $TRIES -ge $MAX_TRIES ]; then
        echo "ERROR: Docker daemon failed to start"
        exit 1
    fi
    sleep 1
done
echo "Docker daemon ready."

# Ensure docker socket is accessible to testuser (docker group)
chmod 666 /var/run/docker.sock 2>/dev/null || true

# Export PATH for testuser (su - resets PATH, so we need to pass it explicitly)
export PATH="/usr/local/bin:/home/testuser/.local/bin:$PATH"

# Switch to test user for remaining operations
if [ "$1" = "/bin/bash" ] || [ "$1" = "bash" ]; then
    echo ""
    echo "Interactive mode. Test user: testuser"
    echo "hal-9000 source: /hal-9000-src"
    echo ""
    echo "Quick start:"
    echo "  cd /hal-9000-src/plugins/hal-9000 && ./install.sh"
    echo ""
    exec su testuser -s /bin/bash
else
    # Run command as testuser preserving environment (no dash = preserve env)
    exec su testuser -s /bin/bash -c "$*"
fi
