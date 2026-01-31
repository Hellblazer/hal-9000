# HAL-9000 Security Monitoring Guide

This guide covers security audit logging, monitoring setup, and incident investigation for HAL-9000.

## Security Log Overview

HAL-9000 maintains two types of logs:

| Log File | Purpose | Retention | Location |
|----------|---------|-----------|----------|
| `security.log` | Security-relevant events only | 90 days | `$HAL9000_HOME/logs/security.log` |
| `audit.log` | General operational events | 30 days | `$HAL9000_HOME/logs/audit.log` |

## Security Events Logged

### Hook Denials (HOOK_DENY)
Logged when a security hook blocks a tool operation.

```
2026-01-31T12:00:00Z | WARN | HOOK_DENY | worker=abc123 tool=Read file=".env" reason="sensitive file"
```

**What to investigate**: Repeated denials may indicate:
- Misconfigured Claude prompts attempting to access secrets
- Potential prompt injection attempts
- Legitimate need to adjust hook configuration

### Authentication Events

**Success (CHROMADB_AUTH_SUCCESS)**:
```
2026-01-31T12:00:01Z | INFO | CHROMADB_AUTH_SUCCESS | worker=abc123 authenticated_worker=abc123 ip=172.17.0.3
```

**Failure (CHROMADB_AUTH_FAILURE)**:
```
2026-01-31T12:00:02Z | WARN | CHROMADB_AUTH_FAILURE | worker=abc123 ip=172.17.0.5 reason="invalid_token"
```

**What to investigate**: Multiple auth failures from same IP may indicate:
- Brute force attempts
- Token expiration issues
- Misconfigured worker

### Bulk Query Detection (BULK_QUERY)
Logged when a query returns an unusually large number of results.

```
2026-01-31T12:00:03Z | WARN | BULK_QUERY | worker=abc123 results=1500 collection=default
```

**Thresholds**:
- `>100 results`: WARN
- `>1000 results`: ERROR (potential data exfiltration)

### Secret Access Attempts (SECRET_ACCESS_ATTEMPT)
Logged when attempting to access sensitive files.

```
2026-01-31T12:00:04Z | WARN | SECRET_ACCESS_ATTEMPT | worker=abc123 tool=Read file=".env"
```

### Symlink Bypass Attempts (SYMLINK_BYPASS_ATTEMPT)
Logged when a file path resolves to a different location via symlink.

```
2026-01-31T12:00:05Z | WARN | SYMLINK_BYPASS_ATTEMPT | worker=abc123 original="/tmp/safe" resolved="/etc/passwd"
```

**What to investigate**: This is almost always an attack attempt.

### Command Blocks (COMMAND_BLOCKED)
Logged when a bash command is blocked by hooks.

```
2026-01-31T12:00:06Z | WARN | COMMAND_BLOCKED | worker=abc123 command="rm -rf /" reason="dangerous rm command"
```

### Syscall Blocks (SYSCALL_BLOCKED)
Logged when seccomp blocks a syscall (if configured).

```
2026-01-31T12:00:07Z | WARN | SYSCALL_BLOCKED | worker=abc123 syscall=ptrace pid=1234 process="suspicious"
```

## Log Format

All security logs use a pipe-delimited format for easy parsing:

```
TIMESTAMP | SEVERITY | EVENT_TYPE | DETAILS
```

- **TIMESTAMP**: ISO 8601 format (UTC)
- **SEVERITY**: INFO, WARN, ERROR, CRITICAL
- **EVENT_TYPE**: Event category (HOOK_DENY, CHROMADB_AUTH_FAILURE, etc.)
- **DETAILS**: Key-value pairs (worker=, tool=, file=, reason=, etc.)

## Monitoring Setup

### 1. Quick Monitoring with watch

```bash
# Watch security log in real-time
watch -n 5 'tail -20 /root/.hal9000/logs/security.log | grep -E "WARN|ERROR|CRITICAL"'

# Count events by type (last 24h)
watch -n 60 'awk -F"|" "{print \$3}" /root/.hal9000/logs/security.log | sort | uniq -c | sort -rn'
```

### 2. Security Event Summary Script

Create `/scripts/security-summary.sh`:

```bash
#!/bin/bash
# Security event summary for last N hours

HOURS="${1:-24}"
LOG_FILE="${HAL9000_HOME:-/root/.hal9000}/logs/security.log"

echo "=== Security Event Summary (last ${HOURS} hours) ==="
echo

# Calculate cutoff time
CUTOFF=$(date -u -d "${HOURS} hours ago" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || \
         date -u -v-${HOURS}H +"%Y-%m-%dT%H:%M:%S")

echo "Events since: $CUTOFF"
echo

# Count by severity
echo "By Severity:"
awk -v cutoff="$CUTOFF" -F'|' '$1 >= cutoff {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' "$LOG_FILE" | \
    sort | uniq -c | sort -rn

echo
echo "By Event Type:"
awk -v cutoff="$CUTOFF" -F'|' '$1 >= cutoff {gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}' "$LOG_FILE" | \
    sort | uniq -c | sort -rn

echo
echo "Recent Warnings/Errors:"
awk -v cutoff="$CUTOFF" -F'|' '$1 >= cutoff' "$LOG_FILE" | grep -E '\| (WARN|ERROR|CRITICAL) \|' | tail -10
```

### 3. Alerting with Prometheus/Grafana

**prometheus.yml snippet**:
```yaml
scrape_configs:
  - job_name: 'hal9000-security'
    static_configs:
      - targets: ['localhost:9101']
    metrics_path: /metrics
```

**Create `/scripts/security-metrics-exporter.sh`**:
```bash
#!/bin/bash
# Export security metrics for Prometheus

LOG_FILE="${HAL9000_HOME:-/root/.hal9000}/logs/security.log"
PORT="${METRICS_PORT:-9101}"

# Count events from last hour
HOUR_AGO=$(date -u -d "1 hour ago" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || \
           date -u -v-1H +"%Y-%m-%dT%H:%M:%S")

WARN_COUNT=$(awk -v cutoff="$HOUR_AGO" -F'|' '$1 >= cutoff && $2 ~ /WARN/' "$LOG_FILE" | wc -l)
ERROR_COUNT=$(awk -v cutoff="$HOUR_AGO" -F'|' '$1 >= cutoff && $2 ~ /ERROR/' "$LOG_FILE" | wc -l)
HOOK_DENY_COUNT=$(awk -v cutoff="$HOUR_AGO" -F'|' '$1 >= cutoff && $3 ~ /HOOK_DENY/' "$LOG_FILE" | wc -l)
AUTH_FAIL_COUNT=$(awk -v cutoff="$HOUR_AGO" -F'|' '$1 >= cutoff && $3 ~ /AUTH_FAILURE/' "$LOG_FILE" | wc -l)

cat << EOF
# HELP hal9000_security_events_total Total security events
# TYPE hal9000_security_events_total counter
hal9000_security_events_warn_1h $WARN_COUNT
hal9000_security_events_error_1h $ERROR_COUNT
hal9000_security_hook_deny_1h $HOOK_DENY_COUNT
hal9000_security_auth_failure_1h $AUTH_FAIL_COUNT
EOF
```

### 4. Integration with SIEM

For enterprise environments, forward logs to your SIEM:

**Filebeat configuration**:
```yaml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /root/.hal9000/logs/security.log
  fields:
    log_type: hal9000-security
  multiline:
    pattern: '^\d{4}-\d{2}-\d{2}T'
    negate: true
    match: after

output.elasticsearch:
  hosts: ["https://elasticsearch:9200"]
  index: "hal9000-security-%{+yyyy.MM.dd}"
```

**Fluent Bit configuration**:
```ini
[INPUT]
    Name        tail
    Path        /root/.hal9000/logs/security.log
    Tag         hal9000.security
    Parser      hal9000_security

[PARSER]
    Name        hal9000_security
    Format      regex
    Regex       ^(?<timestamp>[^\|]+) \| (?<severity>\w+) \| (?<event>\w+) \| (?<details>.*)$
    Time_Key    timestamp
    Time_Format %Y-%m-%dT%H:%M:%SZ

[OUTPUT]
    Name        forward
    Match       hal9000.*
    Host        fluentd.example.com
    Port        24224
```

## Incident Investigation

### Quick Triage Commands

```bash
# Last 50 security events
tail -50 /root/.hal9000/logs/security.log

# All auth failures today
grep "AUTH_FAILURE" /root/.hal9000/logs/security.log | grep "$(date +%Y-%m-%d)"

# Hook denials for specific worker
grep "HOOK_DENY" /root/.hal9000/logs/security.log | grep "worker=abc123"

# Events by IP address
grep "ip=172.17.0.5" /root/.hal9000/logs/security.log

# Timeline of events for specific file
grep "file=\".env\"" /root/.hal9000/logs/security.log
```

### Forensic Investigation

For detailed incident investigation:

```bash
# 1. Identify the scope
grep "worker=WORKER_ID" /root/.hal9000/logs/security.log | head -20

# 2. Build timeline
grep "worker=WORKER_ID" /root/.hal9000/logs/security.log | \
    awk -F'|' '{print $1, $3}' | sort

# 3. Check correlated audit events
grep "WORKER_ID" /root/.hal9000/logs/audit.log

# 4. Export for external analysis
grep "worker=WORKER_ID" /root/.hal9000/logs/security.log > incident-WORKER_ID.log
```

## Log Rotation

Logs are rotated automatically using the built-in rotation in `audit-log.sh`:

- **Max file size**: 10MB (configurable via `AUDIT_LOG_MAX_SIZE`)
- **Max files kept**: 5 (configurable via `AUDIT_LOG_MAX_FILES`)
- **Rotation scheme**: security.log -> security.log.1 -> security.log.2 -> ...

For enterprise deployments, use the provided logrotate configuration:

```bash
# Install logrotate config
cp /path/to/hal-9000/plugins/hal-9000/docker/config/logrotate.conf /etc/logrotate.d/hal9000

# Test rotation
logrotate -d /etc/logrotate.d/hal9000

# Force rotation
logrotate -f /etc/logrotate.d/hal9000
```

## Best Practices

1. **Monitor WARN/ERROR levels**: Set up alerts for anything above INFO
2. **Track auth failures**: More than 5 failures/hour is suspicious
3. **Investigate symlink bypasses**: Almost always malicious
4. **Review bulk queries**: Large result sets may indicate data exfiltration
5. **Archive logs**: Keep security logs for at least 90 days
6. **Secure log access**: Logs should be readable only by root/admins

## Troubleshooting

### Logs Not Being Written

```bash
# Check log directory permissions
ls -la ${HAL9000_HOME:-/root/.hal9000}/logs/

# Ensure directory exists
mkdir -p ${HAL9000_HOME:-/root/.hal9000}/logs
chmod 0750 ${HAL9000_HOME:-/root/.hal9000}/logs

# Check disk space
df -h /root/.hal9000/logs/
```

### Python Hooks Not Logging

```bash
# Enable debug mode
export HAL9000_DEBUG=1

# Check Python path
python3 -c "from security_audit import log_security_event; print('OK')"
```

### Missing Events

Some events require explicit enabling:

```bash
# Enable ChromaDB auth logging (set in parent-entrypoint.sh)
export CHROMADB_AUTH_LOGGING=true

# Enable seccomp syscall logging
export SECCOMP_LOG_BLOCKED=true
```
