# HAL-9000 TMUX Architecture

## Overview

HAL-9000 uses TMUX (Terminal Multiplexer) as the foundation for session management and inter-process communication between parent and worker containers.

## Why TMUX?

### Decision Rationale

TMUX was chosen over alternatives for the following reasons:

#### 1. **Process Management & Lifecycle**
- **TMUX Strength**: Native process management through panes and sessions
- **Alternative (systemd)**: Would require systemd in container (heavyweight, not portable)
- **Alternative (supervisord)**: Requires additional daemon, less interactive
- **Alternative (Docker API)**: Overcomplicated for session management

TMUX provides process state management (running/stopped/detached) without requiring additional system services.

#### 2. **Interactive Session Support**
- **TMUX Strength**: Designed for interactive terminal sessions
- **Alternative (REST API)**: Cannot handle interactive stdin/stdout passthrough
- **Alternative (Message Queue)**: Adds latency, loses terminal control

TMUX excels at maintaining interactive Claude sessions with full TTY support (colors, formatting, cursor control).

#### 3. **Socket-Based IPC**
- **TMUX Strength**: Native Unix socket support (`-S` flag)
- **Alternative (Docker API)**: Requires privileged socket access
- **Alternative (gRPC)**: Adds complexity, serialization overhead
- **Alternative (Named pipes)**: Less flexible than sockets

TMUX sockets provide lightweight inter-container communication that survives container restarts.

#### 4. **Session Persistence**
- **TMUX Strength**: Sessions persist after detach (survives network interruptions)
- **Alternative (In-process state)**: Lost on container restart
- **Alternative (Database)**: Adds operational complexity

Note: TMUX itself does NOT persist Claude state (credentials, plugins, memory bank). Those are persisted separately via file-based storage in shared volumes. TMUX provides the session container for Claude's runtime, not the state persistence mechanism.

#### 5. **Proven Stability**
- TMUX is battle-tested in production environments
- Widely used for distributed computing, HPC clusters, multiplayer terminals
- Minimal dependencies, pure C implementation
- Low memory footprint (~5-10MB per session)

### Rejected Alternatives

#### Docker Exec (Without TMUX)
```bash
docker exec -it worker-1 claude  # Process dies when docker exec closes
```
**Problem**: Each `docker exec` creates a NEW process. Cannot reconnect to existing session.

#### systemd in Container
```dockerfile
RUN systemctl enable hal9000-service
```
**Problem**: Requires system dependencies, init system in container (violates container principles).

#### REST API with gRPC
**Problem**:
- Adds serialization overhead
- Cannot pass TTY/stdin directly
- Increases latency
- Requires authentication/authorization layer

#### Message Queue (RabbitMQ, Kafka)
**Problem**:
- Adds operational complexity
- Not designed for TTY passthrough
- Overkill for session management

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Host                                                        │
│                                                             │
│  /data/tmux-sockets/ (shared volume)                        │
│  ├── parent.sock (TMUX server)                              │
│  ├── worker-1.sock                                          │
│  ├── worker-2.sock                                          │
│  └── worker-N.sock                                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         │                        │
    ┌────▼──────────┐     ┌──────▼────────┐
    │ Parent        │     │ Worker        │
    │ Container     │     │ Containers    │
    │               │     │               │
    │ - Daemon      │     │ - Claude CLI  │
    │ - Pool Mgr    │     │ - MCP Servers │
    │ - Coordinator │     │ - ChromaDB    │
    │ - TMUX Server │     │ - Memory Bank │
    │   (parent.    │     │ - TMUX Client │
    │    sock)      │     │   (worker.    │
    │               │     │    sock)      │
    └───────────────┘     └───────────────┘
```

## Component Roles

### TMUX Server (Parent Container)
**Location**: `parent-entrypoint.sh:init_tmux_server()`

```bash
tmux -S /data/tmux-sockets/parent.sock new-session -d -s parent
```

**Responsibilities**:
- Maintains parent TMUX server process
- Routes all coordinator commands
- Manages parent session state
- Provides socket for worker connections

**Lifecycle**:
- Created on parent container startup
- Destroyed on graceful shutdown
- Auto-respawned if killed unexpectedly

### TMUX Clients (Worker Containers)
**Location**: `spawn-worker.sh:execute_command_in_worker()`

```bash
tmux -S /data/tmux-sockets/worker-1.sock new-session -d -s worker
```

**Responsibilities**:
- Run Claude in isolated TMUX pane
- Maintain process isolation
- Support attach/detach operations
- Handle graceful shutdown

**Lifecycle**:
- Created when worker spawned
- Survives after Claude process exits
- Removed when worker explicitly stopped

### Inter-Container Communication

**Parent → Worker (Commands)**:
```bash
coordinator.sh attach-to-worker "worker-1"
  ↓
docker exec worker-1 tmux -S /data/tmux-sockets/worker-1.sock send-keys "..."
  ↓
TMUX socket forwards to Claude process in pane
```

**Worker → Parent (Status Queries)**:
```bash
docker exec worker-1 tmux -S /data/tmux-sockets/parent.sock list-sessions
  ↓
Parent TMUX server reports registry of all workers
```

## Session Lifecycle

### Creation
```
1. User: hal-9000 /project
   ↓
2. hal-9000 script generates session name: hal-9000-project-abc123
   ↓
3. spawn-worker.sh creates container: docker run --name hal-9000-project-abc123
   ↓
4. Container entrypoint creates TMUX session:
   tmux -S /data/tmux-sockets/worker-abc123.sock new-session -d
   ↓
5. Claude process launched in TMUX pane:
   tmux send-keys "claude" Enter
   ↓
6. Session metadata recorded: ~/.hal9000/sessions/hal-9000-project-abc123.json
```

### Attachment
```
1. User: hal-9000 attach hal-9000-project-abc123
   ↓
2. hal-9000 script locates container: docker ps | grep hal-9000-project-abc123
   ↓
3. Attaches to TMUX session in container:
   docker exec -it <container> tmux -S /data/tmux-sockets/<worker>.sock attach-session
   ↓
4. User connected to Claude in TMUX pane (full TTY support)
```

### Detachment
```
1. User: Ctrl+B, D (TMUX detach key)
   OR
2. User closes terminal
   ↓
3. Claude process continues running in TMUX pane
   ↓
4. Container and worker remain active
   ↓
5. Session data persisted to shared volume
   ↓
6. Can reattach later: hal-9000 attach hal-9000-project-abc123
```

### Termination
```
1. User: hal-9000 stop hal-9000-project-abc123
   ↓
2. coordinator.sh sends TMUX shutdown signal:
   tmux -S /data/tmux-sockets/worker-abc123.sock kill-session
   ↓
3. Claude process terminated (signal 15, SIGTERM)
   ↓
4. Container stops gracefully
   ↓
5. Session metadata cleaned up (optional)
```

## Critical Design Decisions

### 1. Socket-Based Architecture (Not HTTP/REST)

**Decision**: Use TMUX sockets instead of HTTP API

**Rationale**:
- Lower latency (Unix socket vs TCP)
- Direct process attachment (TTY support)
- No authentication overhead
- Simpler debugging

**Tradeoff**:
- Requires shared filesystem for sockets
- Not suitable for truly distributed systems (would use REST)

### 2. One Socket Per Worker (Not Shared Parent Socket)

**Decision**: Each worker gets its own TMUX socket (`worker-N.sock`)

**Rationale**:
- Isolation: One worker crash doesn't affect others
- Scalability: Can spawn unlimited workers
- Auditability: Clear 1:1 mapping of socket to process

**Tradeoff**:
- More sockets to manage
- Coordinator must route to correct socket

### 3. File-Based State Persistence (Not TMUX Persistence)

**Decision**: Store Claude state in files, not TMUX session data

**Rationale**:
- TMUX cannot persist non-TTY state (credentials, configs)
- Files survive container/TMUX server restart
- Works with external tools (backup, sync, audit)

**Not**: "TMUX handles persistence" ❌
**But**: "TMUX provides session container; files store state" ✅

### 4. Detached Sessions for Resilience

**Decision**: Keep TMUX sessions running after Claude detaches

**Rationale**:
- Survive network interruptions
- Resume without restarting Claude
- Maintain session history

**Implication**:
- Containers stay running (CPU minimal, memory <50MB idle)
- Must explicitly stop workers to reclaim resources
- Pool manager auto-cleans idle workers

## Performance Characteristics

### Memory
- TMUX server: ~5-10MB
- TMUX session (idle): ~2-5MB
- Worker container base: ~200MB
- **Total per worker**: ~220-250MB idle, ~500MB+ running Claude

### CPU
- TMUX: Near-zero when idle
- Socket I/O: Sub-millisecond latency
- Session attach: ~500ms (container overhead, not TMUX)

### Socket Throughput
- TMUX socket: ~100MB/s theoretical (rarely tested)
- Typical Claude output: 1-50KB/sec (well below limit)

## Limitations & Future Improvements

### Current Limitations

1. **No Built-In Persistence**
   - TMUX sessions lost if parent crashes
   - File-based state persists, but session metadata doesn't
   - Future: Use persistent TMUX log files

2. **Socket-Based IPC Doesn't Scale Across Hosts**
   - Works within single machine, not distributed
   - Future: Add REST API layer for multi-host setups

3. **No Native Encryption**
   - TMUX sockets unencrypted on host filesystem
   - Future: Use user-defined networks with TLS

4. **Limited Monitoring**
   - No built-in metrics for TMUX performance
   - Future: Add TMUX metrics exporter for Prometheus

### Future Enhancements

1. **User-Defined Networks** (Issue #7)
   - Create Docker custom network for workers
   - Enable Docker DNS for service discovery
   - Better isolation than default bridge

2. **Persistent Session Logs** (Enhancement)
   - Enable TMUX logging (`capture-pane -p > session.log`)
   - Persist session history to shared volume
   - Audit trail of all Claude interactions

3. **Multi-Host Orchestration** (Enhancement)
   - Add HTTP API wrapper around TMUX
   - Enable orchestration across multiple hosts
   - Use Kubernetes-style scheduling

4. **High Availability** (Enhancement)
   - Replicate parent container (secondary with failover)
   - State sync from primary to secondary
   - Zero-downtime failover

## Debugging

### View TMUX Server Processes
```bash
ps aux | grep tmux
# Shows: tmux -S /data/tmux-sockets/parent.sock new-session -d

# In parent container:
tmux -S /data/tmux-sockets/parent.sock list-sessions
```

### List All Worker Sessions
```bash
coordinator.sh list-workers

# Or manually:
for sock in /data/tmux-sockets/worker-*.sock; do
  tmux -S "$sock" list-sessions
done
```

### Attach to Specific Worker
```bash
hal-9000 attach worker-1

# Or manually:
docker exec -it worker-container \
  tmux -S /data/tmux-sockets/worker-1.sock attach-session
```

### Send Command to Worker
```bash
docker exec worker-container \
  tmux -S /data/tmux-sockets/worker-1.sock send-keys "echo 'test'" Enter
```

### Monitor TMUX Activity
```bash
# Follow TMUX logs
docker exec parent-container \
  tail -f /var/log/tmux-parent.log
```

## References

- TMUX Manual: https://man.openbsd.org/tmux
- HAL-9000 Coordinator: `plugins/hal-9000/docker/coordinator.sh`
- Parent Entrypoint: `plugins/hal-9000/docker/parent-entrypoint.sh`
- Worker Spawn: `plugins/hal-9000/docker/spawn-worker.sh`
