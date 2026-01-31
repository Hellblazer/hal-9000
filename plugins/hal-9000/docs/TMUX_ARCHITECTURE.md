# HAL-9000 TMUX-Based Parent-Worker Orchestration

## Overview

HAL-9000 uses TMUX (Terminal Multiplexer) for parent-worker communication and session management. This architecture replaces TTY-based communication (`docker exec -it`) with more robust, isolated inter-process communication via Unix sockets.

## Why TMUX?

The selection of TMUX as the foundation for HAL-9000's orchestration was made after evaluating several alternatives. This section documents the decision rationale, trade-offs, and architectural benefits.

### Alternatives Considered

| Approach | Description | Pros | Cons | Verdict |
|----------|-------------|------|------|---------|
| **GNU Screen** | Alternative terminal multiplexer | Lightweight, similar socket-based IPC | Less mature scripting API, smaller ecosystem, fewer active maintainers | ❌ Rejected - inferior scriptability |
| **Direct Docker Exec** | `docker exec -it` for each command | Simple, no dependencies, built into Docker | Requires TTY allocation, no session persistence, race conditions on attach, no native IPC | ❌ Rejected - unreliable for automation |
| **Custom Daemon** | Write a custom orchestration daemon in Go/Rust | Full control, optimized for exact use case | High development cost, maintenance burden, reinventing terminal multiplexing, debugging complexity | ❌ Rejected - unnecessary complexity |
| **SSH + Screen/TMUX** | Run SSH daemon in containers | Standard remote access pattern | Heavy (sshd per container), authentication complexity, overkill for local IPC | ❌ Rejected - over-engineered |
| **Named Pipes (FIFOs)** | Unix named pipes for IPC | Lightweight, no dependencies | Unidirectional, no built-in multiplexing, manual session management, complex scripting | ❌ Rejected - too low-level |
| **TMUX (Selected)** | Industry-standard terminal multiplexer | Socket-based IPC, mature scripting, session persistence, active development, proven reliability | Additional dependency, learning curve for operators | ✅ **Selected** |

### TMUX Advantages

**1. Socket-Based IPC**
- Unix domain sockets provide reliable, low-latency communication
- Sockets persist in shared Docker volumes (`/data/tmux-sockets`)
- No TTY required - works in non-interactive contexts (automation, CI/CD)
- Supports concurrent connections without race conditions

**2. Session Persistence**
- Claude sessions survive detach/attach cycles
- Worker state maintained in TMUX process (no file-based serialization)
- Eliminates TOCTOU (Time-Of-Check-Time-Of-Use) bugs
- Session survives while parent container runs

**3. Mature Scriptability**
- Extensive command API (`tmux send-keys`, `tmux capture-pane`, `tmux list-sessions`)
- Programmatic control from parent coordinator
- Output capture for logging and debugging
- Window/pane management for multi-window workflows (Claude + shell)

**4. Proven Reliability**
- Decades of production use in DevOps workflows
- Active development and security patches
- Cross-platform (Linux, macOS, BSD)
- Well-documented edge cases and failure modes

**5. Operator Familiarity**
- Widely known in DevOps community
- Standard keybindings and workflows
- Extensive online resources and troubleshooting guides
- Lower training cost for operations teams

### Trade-Offs and Mitigations

| Trade-Off | Impact | Mitigation |
|-----------|--------|------------|
| **Additional Dependency** | TMUX must be installed in containers | Included in base image; negligible size overhead (~500KB); widely available in package repos |
| **Learning Curve** | Operators need TMUX knowledge | Comprehensive documentation; wrapper scripts (`tmux-send.sh`, `attach-worker.sh`) hide complexity; common operations work without TMUX knowledge |
| **Debugging Complexity** | Socket issues can be cryptic | Detailed troubleshooting guide; `show-workers.sh` provides socket health checks; clear error messages in coordinator |
| **Socket Permissions** | Incorrect permissions break IPC | Automated permission checks in `spawn-worker.sh`; `chmod 0770` enforcement; documented in SECURITY.md |

### Decision Rationale

**Primary Drivers:**
1. **Reliability** - Production-proven for 20+ years in similar use cases (CI/CD, remote development, server administration)
2. **Automation-Friendly** - Socket-based IPC works in non-interactive contexts (critical for CI/CD, testing, and scripting)
3. **Session Persistence** - Maintains Claude state across detach/attach without file-based serialization (eliminates race conditions)
4. **Scriptability** - Rich command API enables programmatic control from parent coordinator

**Why Not Custom Solution?**
Building a custom daemon would require:
- Reimplementing terminal multiplexing primitives
- Handling edge cases TMUX already solves (resizing, signal handling, escape sequences)
- Ongoing maintenance and security patching
- Extensive testing across platforms and Docker versions

TMUX provides all required functionality out-of-the-box, with decades of hardening and a mature ecosystem.

**Why Not Direct Docker Exec?**
`docker exec -it` has fundamental limitations:
- **TTY requirement** breaks automation
- **No persistence** - each exec is independent
- **Race conditions** - concurrent attaches cause corruption
- **No native IPC** - requires polling or complex signaling

TMUX solves all these issues with socket-based IPC and built-in session management.

### Architectural Fit

TMUX aligns perfectly with HAL-9000's requirements:

| Requirement | How TMUX Addresses It |
|-------------|----------------------|
| **Parent-Worker IPC** | Unix domain sockets in shared volume (`/data/tmux-sockets`) |
| **Session Persistence** | TMUX process maintains state (no save/restore race conditions) |
| **Automation Support** | Socket-based commands work without TTY |
| **Concurrent Access** | Multiple connections to same session (coordinator + operator) |
| **Isolation** | Each worker has independent TMUX server (socket per worker) |
| **Monitoring** | `tmux list-sessions`, `tmux list-panes` for health checks |
| **Debugging** | Capture pane output, send commands, inspect window state |
| **Scalability** | Minimal overhead per worker (~5MB per TMUX server process) |

## Architecture

```
HOST MACHINE
  │
  └─ Docker Daemon
       │
       ├─ Parent Container (hal9000-parent)
       │  └─ TMUX Server: /data/tmux-sockets/parent.sock
       │     └─ Session: hal9000-coordinator
       │        ├─ Window: coordinator (monitors workers)
       │        └─ Window: status (dashboard)
       │
       ├─ Worker Container 1 (hal9000-worker-abc123)
       │  └─ TMUX Server: /data/tmux-sockets/worker-hal9000-worker-abc123.sock
       │     └─ Session: worker-hal9000-worker-abc123
       │        ├─ Window: 0 (Claude CLI running)
       │        └─ Window: 1 (Debug shell)
       │
       └─ Worker Container 2 (hal9000-worker-def456)
          └─ TMUX Server: /data/tmux-sockets/worker-hal9000-worker-def456.sock
             └─ Session: worker-hal9000-worker-def456
                ├─ Window: 0 (Claude CLI running)
                └─ Window: 1 (Debug shell)

Shared Volumes (IPC & State):
  ├─ hal9000-tmux-sockets/ → /data/tmux-sockets
  │  ├─ parent.sock → Parent's TMUX server socket
  │  ├─ worker-hal9000-worker-abc123.sock → Worker 1's TMUX server socket
  │  └─ worker-hal9000-worker-def456.sock → Worker 2's TMUX server socket
  │
  ├─ hal9000-coordinator-state/ → /data/coordinator-state
  │  ├─ workers.json → {worker_id: {status, session_info, ...}}
  │  └─ sessions.json → {worker_id: {tmux_session, panes, ...}}
  │
  └─ (other volumes for CLAUDE_HOME, memory-bank, etc.)
```

## Key Design Decisions

### 1. Independent TMUX Servers Per Worker
- **Benefit**: Complete isolation - each worker has independent TMUX daemon
- **Socket Location**: `/data/tmux-sockets/worker-{WORKER_NAME}.sock`
- **Access**: Via shared volume mount (Unix domain socket)
- **Reliability**: Socket survives container restarts (persists in volume)

### 2. Network Decoupling
- **Old Approach**: Workers shared parent's network namespace (`--network=container:parent`)
- **New Approach**: Workers use bridge network for isolation
- **Service Access**: Parent services (ChromaDB) accessed via parent IP address
- **Benefits**: Better security, simpler distribution, cleaner namespace separation

### 3. Hybrid TMUX Architecture
- **Parent**: Runs single TMUX server for coordination
- **Workers**: Each has independent TMUX server
- **Communication**: Via shared socket volume + JSON registry
- **Scalability**: Parent doesn't manage all sessions - each worker is autonomous

### 4. Session State Management
- **No Save/Restore Races**: Claude session runs in TMUX, not stored/restored
- **Persistence**: TMUX session maintains Claude's state across detach/attach
- **Cross-Container**: Memory Bank MCP for persistent state across containers
- **No TOCTOU Issues**: TMUX handles synchronization internally

## Control Utilities

Three primary tools for worker management:

### 1. tmux-list-sessions.sh - Discover Available Workers
```bash
# List all worker sessions
/scripts/tmux-list-sessions.sh

# Verbose output
/scripts/tmux-list-sessions.sh -v

# JSON output
/scripts/tmux-list-sessions.sh --json
```

**Output**:
```
TMUX Sessions:
  hal9000-worker-abc123 (socket: /data/tmux-sockets/worker-hal9000-worker-abc123.sock) [✓]
  hal9000-worker-def456 (socket: /data/tmux-sockets/worker-hal9000-worker-def456.sock) [✓]
  parent (coordinator) [socket: /data/tmux-sockets/parent.sock]

Total: 2 worker session(s)
```

### 2. tmux-send.sh - Send Commands Programmatically
```bash
# Send command and capture output
/scripts/tmux-send.sh worker-abc "bd ready" -c

# Send command without output capture
/scripts/tmux-send.sh hal9000-worker-abc123 "pwd"

# Send multi-line commands
/scripts/tmux-send.sh worker-abc "echo hello && sleep 1"
```

**Use Cases**:
- Automation scripts
- CI/CD pipelines
- Batch operations across workers
- Remote command execution

### 3. tmux-attach.sh - Interactive Session Access
```bash
# Attach to Claude window (default)
/scripts/tmux-attach.sh worker-abc

# Attach to shell window
/scripts/tmux-attach.sh worker-abc shell

# List windows before attaching
/scripts/tmux-attach.sh worker-abc -l
```

**TMUX Commands** (while attached):
- `Ctrl+B D` - Detach and keep session running
- `Ctrl+B C` - Create new window
- `Ctrl+B N` / `Ctrl+B P` - Next/Previous window
- `Ctrl+B ,` - Rename current window

## Coordinator Monitoring

The parent coordinator continuously monitors worker lifecycle:

### Registry File: `/data/coordinator-state/workers.json`
```json
{
  "hal9000-worker-abc123": {
    "status": "running",
    "tmux_socket": "/data/tmux-sockets/worker-hal9000-worker-abc123.sock",
    "tmux_ready": true,
    "container_id": "abc123def456...",
    "created_at": "2026-01-30T16:00:00Z"
  },
  "hal9000-worker-def456": {
    "status": "running",
    "tmux_socket": "/data/tmux-sockets/worker-hal9000-worker-def456.sock",
    "tmux_ready": true,
    "container_id": "def456ghi789...",
    "created_at": "2026-01-30T16:05:00Z"
  }
}
```

### Monitoring Loop
```bash
# Coordinator checks:
1. Every 5 seconds: Health check (logged every 60s)
2. Every 30 seconds: Update worker registry
3. Every 30 seconds: Validate TMUX sessions (cleanup stale sockets)
```

## Troubleshooting

### Issue: Worker Session Not Found
```bash
# Check if socket exists
ls -la /data/tmux-sockets/worker-*.sock

# Check if container is running
docker ps | grep worker-abc

# Verify coordinator registry
cat /data/coordinator-state/workers.json | jq
```

### Issue: Command Fails with "Worker not found"
```bash
# Verify worker name format
# Valid: worker-abc, hal9000-worker-abc123
# The script will normalize: abc → hal9000-worker-abc

# If socket is missing, worker hasn't started its TMUX server yet
# Wait a moment and try again
sleep 2
/scripts/tmux-list-sessions.sh
```

### Issue: TMUX Session Frozen
```bash
# Detach without killing session
# Press Ctrl+B, then D

# If completely frozen, from host:
tmux -S /data/tmux-sockets/worker-XXXXX.sock kill-session -t worker-XXXXX

# Session will be recreated when container restarts
```

### Issue: Network Connectivity
```bash
# Check ChromaDB is accessible from worker
docker exec CONTAINER_NAME curl http://$PARENT_IP:8000/api/v2/heartbeat

# View ChromaDB host configuration
docker exec CONTAINER_NAME env | grep CHROMADB
```

## Performance Characteristics

| Operation | Time | Notes |
|-----------|------|-------|
| Create worker TMUX session | 50-100ms | Socket created, session established |
| Send command | 10-20ms | Command queued in TMUX pane |
| Capture output | 5-50ms | Depends on pane content size |
| Attach interactive | <1ms | Near-instant (local socket) |
| List all sessions | 100-200ms | Scans socket directory + Docker inspect |

## Security Considerations

### Socket Permissions
- Directory: `/data/tmux-sockets` with mode 0777 (world-writable)
- Sockets inherit permissions from parent container's TMUX process
- **Note**: In production, restrict to specific user/group if possible

### Network Isolation
- Workers use independent bridge networks (not shared namespace)
- Network traffic between containers is isolated
- ChromaDB access via parent IP (single point of network exposure)

### Session Isolation
- Each worker's TMUX session is independent
- No cross-worker command injection via TMUX
- Sessions identified by worker container name (Docker-controlled namespace)

## Future Enhancements

### Distributed Deployment
- Sockets on network volumes (NFS, SMB) for remote workers
- HTTP API wrapper for remote TMUX access
- Load balancing across worker pools

### Advanced Features
- Session recording (TMUX script language)
- Output streaming (WebSocket relay)
- Session replication for HA
- Resource-based scheduling

### Integration
- Kubernetes StatefulSet controller
- REST API for session management
- Web UI for session browser/viewer
- Integration with monitoring systems

## References

- TMUX Manual: `man tmux`
- Socket Specification: Unix Domain Sockets (AF_UNIX)
- HAL-9000 Coordinator: `/scripts/coordinator.sh`
- Control Scripts: `/scripts/tmux-{send,attach,list-sessions}.sh`
