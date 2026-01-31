# HAL-9000 Seccomp Security Profiles

Custom seccomp (secure computing mode) profiles for HAL-9000 Docker containers to restrict syscall access and improve security posture.

## Overview

Seccomp is a Linux kernel security feature that restricts which system calls a process can make. By limiting syscall access, we reduce the attack surface and prevent privilege escalation attempts.

## Profiles

### `hal9000-base.json` - Production Profile

Restrictive seccomp profile for HAL-9000 worker containers.

**Blocks dangerous syscalls:**
- Kernel module operations (`init_module`, `delete_module`, `finit_module`)
- System time modification (`settimeofday`, `clock_settime`, `stime`)
- Kernel loading (`kexec_load`, `kexec_file_load`)
- Filesystem mounting (`mount`, `umount`, `pivot_root`)
- Namespace manipulation beyond Docker control (`setns`, `unshare`)
- Process tracing (`ptrace`)
- Performance monitoring (`perf_event_open`)
- Raw I/O port access (`ioperm`, `iopl`)
- System reboot (`reboot`)
- Kernel keyring (`add_key`, `keyctl`, `request_key`)
- BPF programs (`bpf`)
- Memory policy (`mbind`, `set_mempolicy`, `migrate_pages`)
- Syslog access (`syslog`)
- Swap operations (`swapon`, `swapoff`)
- System information (`_sysctl`, `sysfs`)

**Allows necessary syscalls:**
- File operations (read, write, open, close, etc.)
- Network operations (socket, connect, bind, listen, etc.)
- Process management (fork, exec, clone, exit, etc.)
- Memory management (mmap, mprotect, brk, etc.)
- Signal handling (sigaction, sigreturn, etc.)
- Time operations (read-only: clock_gettime, gettimeofday)
- IPC (pipes, sockets, semaphores, message queues)

**Architecture support:**
- x86_64 (primary)
- x86 (32-bit compatibility)
- aarch64 (ARM 64-bit)
- arm (ARM 32-bit)

### `hal9000-audit.json` - Testing Profile

Audit-mode profile that logs violations without blocking.

**Purpose:**
- Test seccomp configuration before enforcing
- Identify syscalls needed by Claude CLI and MCP servers
- Validate profile doesn't break functionality

**Usage:**
Set `defaultAction: SCMP_ACT_LOG` to log syscall violations without blocking. Review logs to ensure profile doesn't interfere with normal operations.

## Usage

### Apply to Container

#### Using hal-9000 Script

The hal-9000 script automatically applies seccomp profiles to worker containers:

```bash
# Production mode (enforcing)
hal-9000 /path/to/project

# Audit mode (logging only)
HAL9000_SECCOMP_MODE=audit hal-9000 /path/to/project
```

#### Using Docker Directly

```bash
# Apply production profile
docker run --security-opt seccomp=/path/to/hal9000-base.json \
  ghcr.io/hellblazer/hal-9000:base

# Apply audit profile
docker run --security-opt seccomp=/path/to/hal9000-audit.json \
  ghcr.io/hellblazer/hal-9000:base

# Disable seccomp (not recommended)
docker run --security-opt seccomp=unconfined \
  ghcr.io/hellblazer/hal-9000:base
```

### Testing Workflow

1. **Start with audit mode:**
   ```bash
   HAL9000_SECCOMP_MODE=audit hal-9000 /tmp/test-project
   ```

2. **Run typical Claude CLI operations:**
   - Help commands
   - MCP server operations
   - File operations
   - Network requests (API calls)

3. **Check audit logs:**
   ```bash
   # On Linux
   sudo journalctl -k | grep audit | grep SECCOMP

   # Or check container logs
   docker logs <container-id> 2>&1 | grep -i seccomp
   ```

4. **Verify no critical syscalls blocked:**
   - If operations fail, check which syscalls were blocked
   - Add necessary syscalls to allowlist if legitimate
   - Keep dangerous syscalls blocked

5. **Switch to production mode:**
   ```bash
   # Remove audit mode env var
   unset HAL9000_SECCOMP_MODE
   hal-9000 /tmp/test-project
   ```

## Security Benefits

### Attack Surface Reduction
- **66 dangerous syscalls blocked** in production mode
- Prevents kernel module loading attacks
- Blocks privilege escalation via namespace manipulation
- Prevents container breakout attempts

### Defense in Depth
- Complements Docker's built-in security
- Works with AppArmor/SELinux
- Additional layer beyond capabilities dropping
- Limits blast radius of compromised container

### Compliance
- Meets CIS Docker Benchmark recommendations
- Aligns with NIST container security guidelines
- Supports security audit requirements

## Blocked Syscalls Reference

### Kernel Module Operations
- `init_module`, `finit_module` - Load kernel modules
- `delete_module` - Remove kernel modules
- `query_module`, `get_kernel_syms` - Query module info

### System Time Modification
- `settimeofday` - Set system time (legacy)
- `clock_settime`, `clock_settime64` - Set system clock
- `stime` - Set system time (very old)

### Kernel and Boot
- `kexec_load`, `kexec_file_load` - Load new kernel
- `reboot` - Reboot system

### Filesystem
- `mount`, `umount`, `umount2` - Mount/unmount filesystems
- `pivot_root` - Change root filesystem
- `swapon`, `swapoff` - Enable/disable swap

### Namespace and Isolation
- `setns` - Join namespace (bypass container isolation)
- `unshare` - Create new namespaces

### Process Inspection
- `ptrace` - Trace processes (debugging/inspection)
- `process_vm_readv`, `process_vm_writev` - Read/write process memory
- `kcmp` - Compare kernel structures

### System Administration
- `setdomainname`, `sethostname` - Change domain/hostname
- `acct` - Process accounting
- `quotactl` - Disk quota control
- `syslog` - Read kernel log

### Kernel Keys and Security
- `add_key`, `keyctl`, `request_key` - Kernel keyring operations

### Performance Monitoring
- `perf_event_open` - Performance event monitoring (can leak info)

### Memory Management
- `mbind`, `set_mempolicy`, `migrate_pages` - NUMA memory policy
- `move_pages` - Move process pages across NUMA nodes
- `get_mempolicy` - Get NUMA memory policy

### I/O and Hardware
- `ioperm`, `iopl` - I/O port permissions
- `modify_ldt` - Modify process LDT (local descriptor table)

### Deprecated/Obsolete
- `uselib` - Load shared library (obsolete)
- `vm86`, `vm86old` - Enter virtual 8086 mode
- `_sysctl` - Read/write system parameters (deprecated)
- `sysfs`, `ustat` - Get filesystem info (obsolete)
- `lookup_dcookie` - Get path from dcookie (rare)
- `nfsservctl` - NFS daemon control (removed)
- `vhangup` - Hang up current terminal

### File Handles
- `name_to_handle_at`, `open_by_handle_at` - Bypass normal permissions

### BPF
- `bpf` - Berkeley Packet Filter programs (powerful, can be dangerous)

### User Fault
- `userfaultfd` - User-space page fault handling

## Monitoring and Debugging

### Check Active Profile

```bash
# Inspect container seccomp status
docker inspect <container> | jq '.[].HostConfig.SecurityOpt'

# Check if seccomp is enforced
grep Seccomp /proc/<pid>/status
```

### Analyze Blocked Syscalls

If operations fail after applying seccomp profile:

1. **Run in audit mode first:**
   ```bash
   HAL9000_SECCOMP_MODE=audit hal-9000 /tmp/test
   ```

2. **Reproduce the failure**

3. **Check audit logs:**
   ```bash
   sudo ausearch -m SECCOMP -ts recent
   # Or
   sudo journalctl -k | grep SECCOMP
   ```

4. **Identify the syscall:**
   - Look for `syscall=<number>` in logs
   - Map syscall number to name: `ausyscall <number>`

5. **Evaluate if syscall should be allowed:**
   - Is it necessary for Claude CLI operation?
   - Is it safe to allow?
   - Can the operation be done differently?

## Customization

### Adding Syscalls

If legitimate operations require additional syscalls:

1. Identify the syscall name
2. Add to `syscalls[0].names` array in `hal9000-base.json`
3. Test thoroughly
4. Document the reason for addition

### Profile Variants

Create profile variants for different use cases:

- `hal9000-dev.json` - Development mode (less restrictive)
- `hal9000-ci.json` - CI/CD environment (moderate restrictions)
- `hal9000-prod.json` - Production (maximum restrictions)

## Limitations

### Known Limitations

1. **Not a complete security solution** - Seccomp is one layer of defense
2. **Allowed syscalls can still be dangerous** - File operations, network, etc.
3. **Syscall arguments not fully validated** - Most syscalls allowed without arg checks
4. **Platform-specific** - Linux kernel feature only
5. **Can break legitimate operations** - Test thoroughly

### Docker Desktop Note

Docker Desktop (macOS/Windows) uses a Linux VM. Seccomp profiles work but:
- Audit logs may be harder to access
- Some syscalls may behave differently
- Test on Linux for production deployment

## References

- [Docker Seccomp Security Profiles](https://docs.docker.com/engine/security/seccomp/)
- [Linux Seccomp Documentation](https://www.kernel.org/doc/Documentation/prctl/seccomp_filter.txt)
- [Seccomp(2) Man Page](https://man7.org/linux/man-pages/man2/seccomp.2.html)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [NIST Application Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)

## License

Apache 2.0 - See LICENSE file for details
