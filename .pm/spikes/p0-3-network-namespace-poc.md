# P0-3: Docker Network Namespace Sharing POC

**Bead**: hal-9000-f6t.7.3
**Date**: 2026-01-25
**Status**: VALIDATED

## Objective

Validate that workers can reach parent's localhost via `--network=container:parent`.

## Test Results

### Test 1: Parent Container with HTTP Server

**Command**:
```bash
docker run -d --name test-parent \
  -p 3001:3001 \
  python:3.11-slim \
  python -m http.server 3001
```

**Result**: SUCCESS
- Container ID: 0ef575567c59
- Status: Up and listening on 0.0.0.0:3001->3001/tcp

### Test 2: Single Worker Connectivity

**Command**:
```bash
docker run --rm \
  --network=container:test-parent \
  curlimages/curl \
  curl -s http://localhost:3001/
```

**Result**: SUCCESS
- Worker successfully reached parent's HTTP server via localhost:3001
- Received HTML directory listing from Python's http.server
- Worker container has no network of its own (shares parent's namespace)

### Test 3: Multiple Workers Simultaneously

**Commands**:
```bash
# Start 3 workers sharing parent's network
docker run -d --name test-worker-1 --network=container:test-parent curlimages/curl sleep 30
docker run -d --name test-worker-2 --network=container:test-parent curlimages/curl sleep 30
docker run -d --name test-worker-3 --network=container:test-parent curlimages/curl sleep 30

# Test connectivity from each
docker exec test-worker-1 curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:3001/
docker exec test-worker-2 curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:3001/
docker exec test-worker-3 curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:3001/
```

**Results**:
| Worker | Status | HTTP Code |
|--------|--------|-----------|
| test-worker-1 | SUCCESS | 200 |
| test-worker-2 | SUCCESS | 200 |
| test-worker-3 | SUCCESS | 200 |

### Test 4: Network Namespace Verification

Verified that workers truly share the parent's network namespace by comparing `/proc/net/tcp`:

- Parent and workers see **identical** TCP socket table
- Same inode numbers (e.g., 9406 for listening socket)
- Same local address bindings (0.0.0.0:0BB9 = 0.0.0.0:3001)

This confirms they're in the same network namespace, not just connected to the same network.

## Gotchas Discovered

1. **No network column for workers**: When using `--network=container:parent`, workers don't have their own network listed in `docker ps` - they share the parent's entirely.

2. **Port binding on parent only**: The `-p 3001:3001` flag must be on the parent container. Workers cannot bind ports since they don't own the network namespace.

3. **Container must be running**: The `--network=container:NAME` requires the target container to be running. If parent stops, workers lose network access.

4. **DNS resolution**: Workers share parent's DNS resolution (from `/etc/resolv.conf` in the shared network namespace).

## Implications for hal9000

1. **Parent container pattern**: The hal9000 parent container should:
   - Own the network namespace
   - Expose ports for MCP servers (3001, 3002, etc.)
   - Run continuously while workers spawn/die

2. **Worker spawning**: Workers use `--network=container:hal9000-parent` to reach localhost services.

3. **MCP server access**: Workers can reach MCP servers on localhost:PORT because they share the parent's network namespace where those ports are bound.

4. **No port conflicts**: Workers don't need their own port bindings - they just connect to services running in the shared namespace.

## Clean Up

```bash
docker rm -f test-parent test-worker-1 test-worker-2 test-worker-3
```

## GO/NO-GO Recommendation

### GO

**Rationale**:
- Network namespace sharing via `--network=container:parent` works exactly as needed
- Multiple workers can simultaneously access localhost services
- No additional networking configuration required
- No Docker network bridges or custom networks needed
- Simple and deterministic - workers just reference parent container

**Confidence Level**: HIGH

This approach is simpler than alternatives (bridge networks, host networking) and provides exactly the isolation model we need: workers share network with parent but have separate process/filesystem namespaces.

## Next Steps

1. Integrate into hal9000 Dockerfile as the standard worker spawn pattern
2. Document the `--network=container:hal9000` flag in worker launch scripts
3. Test with actual MCP server processes (not just HTTP server)
