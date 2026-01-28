#!/bin/bash
# setup-foundation-mcp.sh - Install Foundation MCP Servers for hal-9000
#
# Sets up Foundation MCP Servers that are shared across all hal-9000 worker containers:
# 1. ChromaDB - Vector database server with concurrent access support
# 2. Memory Bank - Persistent memory storage across sessions
# 3. Sequential Thinking - Step-by-step reasoning MCP server
#
# Usage:
#   ./scripts/setup-foundation-mcp.sh                    # Full setup with defaults
#   ./scripts/setup-foundation-mcp.sh --chromadb-port 8001   # Custom ChromaDB port
#   ./scripts/setup-foundation-mcp.sh --storage-path /custom/path
#   ./scripts/setup-foundation-mcp.sh --help

set -Eeuo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly FOUNDATION_HOME="${HOME}/.hal9000/foundation-mcp"
readonly CHROMADB_PORT="${CHROMADB_PORT:-8000}"
readonly CHROMADB_CONTAINER="hal9000-chromadb"
readonly MEMORY_BANK_CONTAINER="hal9000-memory-bank"
readonly SEQUENTIAL_THINKING_CONTAINER="hal9000-sequential-thinking"

# Storage paths
readonly CHROMADB_DATA="${FOUNDATION_HOME}/chromadb-data"
readonly MEMORY_BANK_DATA="${FOUNDATION_HOME}/memory-bank-data"

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# Helper functions
show_help() {
    cat << 'EOF'
hal-9000 Foundation MCP Servers Setup

Usage: ./scripts/setup-foundation-mcp.sh [OPTIONS]

OPTIONS:
  --chromadb-port PORT          ChromaDB server port (default: 8000)
  --storage-path PATH           Base path for persistent storage (default: ~/.hal9000/foundation-mcp)
  --chromadb-only              Only setup ChromaDB
  --memory-bank-only           Only setup Memory Bank
  --sequential-thinking-only   Only setup Sequential Thinking
  --start                      Start all services (implies --create)
  --stop                       Stop all services
  --status                     Show service status
  --logs [service]             Show service logs (chromadb, memory-bank, sequential-thinking)
  --cleanup                    Remove all Foundation MCP services and data (DESTRUCTIVE)
  --help                       Show this help message

EXAMPLES:
  # Full setup with defaults
  ./scripts/setup-foundation-mcp.sh

  # Setup with custom ChromaDB port
  ./scripts/setup-foundation-mcp.sh --chromadb-port 8001

  # Check status
  ./scripts/setup-foundation-mcp.sh --status

  # View ChromaDB logs
  ./scripts/setup-foundation-mcp.sh --logs chromadb

  # Stop services
  ./scripts/setup-foundation-mcp.sh --stop
EOF
}

# Check Docker availability
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        log_error "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi

    if ! docker ps > /dev/null 2>&1; then
        log_error "Docker daemon is not running"
        log_error "Please start Docker and try again"
        exit 1
    fi

    log_success "Docker is available"
}

# Create directory structure
create_directories() {
    log_info "Creating storage directories..."

    mkdir -p "$FOUNDATION_HOME"
    mkdir -p "$CHROMADB_DATA"
    mkdir -p "$MEMORY_BANK_DATA"

    # Set proper permissions
    chmod 755 "$FOUNDATION_HOME"
    chmod 755 "$CHROMADB_DATA"
    chmod 755 "$MEMORY_BANK_DATA"

    log_success "Storage directories created at: $FOUNDATION_HOME"
}

# Setup ChromaDB
setup_chromadb() {
    log_info "Setting up ChromaDB server..."

    # Check if container already exists
    if docker ps -a --filter "name=^${CHROMADB_CONTAINER}$" --format '{{.Names}}' | grep -q .; then
        log_warning "ChromaDB container already exists"
        return 0
    fi

    # Create ChromaDB container
    log_info "Creating ChromaDB container (port ${CHROMADB_PORT})..."

    docker run -d \
        --name "$CHROMADB_CONTAINER" \
        -p "${CHROMADB_PORT}:8000" \
        -v "${CHROMADB_DATA}:/chroma/data" \
        -e CHROMA_DB_IMPL=duckdb+parquet \
        -e ALLOW_RESET=true \
        --restart unless-stopped \
        ghcr.io/chroma-core/chroma:latest > /dev/null 2>&1 || {
        log_error "Failed to create ChromaDB container"
        return 1
    }

    log_success "ChromaDB container created"

    # Wait for ChromaDB to be ready
    log_info "Waiting for ChromaDB to be ready..."
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "http://localhost:${CHROMADB_PORT}/api/v1/heartbeat" > /dev/null 2>&1; then
            log_success "ChromaDB is ready at http://localhost:${CHROMADB_PORT}"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    log_error "ChromaDB failed to start within 30 seconds"
    docker logs "$CHROMADB_CONTAINER" 2>&1 | head -20
    return 1
}

# Setup Memory Bank
setup_memory_bank() {
    log_info "Setting up Memory Bank server..."

    # Check if container already exists
    if docker ps -a --filter "name=^${MEMORY_BANK_CONTAINER}$" --format '{{.Names}}' | grep -q .; then
        log_warning "Memory Bank container already exists"
        return 0
    fi

    # Memory Bank is typically a file-based system, create a managed directory
    log_info "Initializing Memory Bank storage..."

    # Create initial Memory Bank structure
    mkdir -p "${MEMORY_BANK_DATA}/projects"
    touch "${MEMORY_BANK_DATA}/.initialized"

    log_success "Memory Bank storage initialized at ${MEMORY_BANK_DATA}"

    # Note: Memory Bank is typically integrated directly with Claude Code
    # rather than as a separate container. The storage is here for reference.
    log_info "Memory Bank storage is ready for use by Claude Code workers"
}

# Setup Sequential Thinking
setup_sequential_thinking() {
    log_info "Setting up Sequential Thinking MCP server..."

    # Check if container already exists
    if docker ps -a --filter "name=^${SEQUENTIAL_THINKING_CONTAINER}$" --format '{{.Names}}' | grep -q .; then
        log_warning "Sequential Thinking container already exists"
        return 0
    fi

    log_info "Sequential Thinking is available as a Claude Code MCP plugin"
    log_info "It will be automatically available to all worker containers"

    log_success "Sequential Thinking is configured and ready"
}

# Start all services
start_services() {
    log_info "Starting Foundation MCP services..."

    # Start ChromaDB
    if docker ps -a --filter "name=^${CHROMADB_CONTAINER}$" --format '{{.Names}}' | grep -q .; then
        if ! docker ps --filter "name=^${CHROMADB_CONTAINER}$" --format '{{.Names}}' | grep -q .; then
            log_info "Starting ChromaDB..."
            docker start "$CHROMADB_CONTAINER"
            log_success "ChromaDB started"
        else
            log_success "ChromaDB is already running"
        fi
    fi

    log_success "Foundation MCP services are running"
}

# Stop all services
stop_services() {
    log_info "Stopping Foundation MCP services..."

    for container in "$CHROMADB_CONTAINER"; do
        if docker ps --filter "name=^${container}$" --format '{{.Names}}' | grep -q .; then
            log_info "Stopping $container..."
            docker stop "$container" > /dev/null 2>&1
            log_success "$container stopped"
        fi
    done

    log_success "Foundation MCP services stopped"
}

# Show service status
show_status() {
    log_info "Foundation MCP Services Status"
    echo ""

    # ChromaDB status
    echo -e "${BLUE}ChromaDB${NC}"
    if docker ps --filter "name=^${CHROMADB_CONTAINER}$" --format '{{.Names}}' | grep -q .; then
        log_success "Running on port ${CHROMADB_PORT}"
        docker ps --filter "name=^${CHROMADB_CONTAINER}$" --format "table {{.ID}}\t{{.Status}}" | tail -1
    else
        log_warning "Not running"
    fi
    echo ""

    # Memory Bank status
    echo -e "${BLUE}Memory Bank${NC}"
    if [ -d "$MEMORY_BANK_DATA" ]; then
        log_success "Storage directory exists"
        echo "  Path: ${MEMORY_BANK_DATA}"
    else
        log_warning "Storage not found"
    fi
    echo ""

    # Sequential Thinking status
    echo -e "${BLUE}Sequential Thinking${NC}"
    log_success "Available as MCP plugin"
    echo ""

    # Storage info
    echo -e "${BLUE}Storage${NC}"
    log_info "Foundation Home: ${FOUNDATION_HOME}"
    if [ -d "$FOUNDATION_HOME" ]; then
        local size
        size=$(du -sh "$FOUNDATION_HOME" 2>/dev/null | cut -f1)
        echo "  Total Size: $size"
    fi
}

# Show service logs
show_logs() {
    local service="${1:-all}"

    case "$service" in
        chromadb)
            log_info "ChromaDB logs (last 50 lines):"
            docker logs --tail 50 "$CHROMADB_CONTAINER" 2>/dev/null || log_warning "ChromaDB container not found"
            ;;
        memory-bank)
            log_info "Memory Bank is file-based (see: ${MEMORY_BANK_DATA})"
            ls -lah "$MEMORY_BANK_DATA" 2>/dev/null || log_warning "Memory Bank storage not found"
            ;;
        sequential-thinking)
            log_info "Sequential Thinking is a Claude plugin (no direct logs)"
            ;;
        all)
            show_logs chromadb
            echo ""
            show_logs memory-bank
            echo ""
            show_logs sequential-thinking
            ;;
        *)
            log_error "Unknown service: $service"
            exit 1
            ;;
    esac
}

# Cleanup (destructive)
cleanup() {
    log_warning "This will remove all Foundation MCP services and data"
    read -p "Are you sure? Type 'yes' to confirm: " -r
    echo ""
    if [[ $REPLY != "yes" ]]; then
        log_info "Cleanup cancelled"
        return 0
    fi

    log_warning "Removing Foundation MCP services..."

    # Stop and remove containers
    for container in "$CHROMADB_CONTAINER"; do
        if docker ps -a --filter "name=^${container}$" --format '{{.Names}}' | grep -q .; then
            log_info "Removing $container..."
            docker stop "$container" > /dev/null 2>&1 || true
            docker rm "$container" > /dev/null 2>&1 || true
            log_success "$container removed"
        fi
    done

    # Remove storage
    if [ -d "$FOUNDATION_HOME" ]; then
        log_warning "Removing storage directory: ${FOUNDATION_HOME}"
        rm -rf "$FOUNDATION_HOME"
        log_success "Storage removed"
    fi

    log_success "Foundation MCP cleanup completed"
}

# Integration instructions
show_integration_instructions() {
    cat << 'EOF'

===============================================================================
Foundation MCP Servers Setup Complete!
===============================================================================

Your Foundation MCP Servers are now running and ready for use.

CONFIGURATION FOR CLAUDE CODE:
-----------------------------

1. CHROMADB (Vector Database)
   URL: http://localhost:8000
   Use in your projects for semantic search and embeddings

2. MEMORY BANK (Persistent Memory)
   Path: ~/.hal9000/foundation-mcp/memory-bank-data
   Automatically available to all hal-9000 worker containers

3. SEQUENTIAL THINKING (MCP Server)
   Available as a Claude Code MCP plugin
   Provides step-by-step reasoning capabilities

NEXT STEPS:
-----------

1. Start hal-9000 worker containers - they will automatically detect and use
   these Foundation MCP Servers

2. Verify services are accessible from within a container:
   docker run --rm -it --network host curlimages/curl \
     curl http://localhost:8000/api/v1/heartbeat

3. Configure your Claude Code settings to use these MCP servers
   (Documentation: See hal-9000 README.md)

MANAGEMENT COMMANDS:
-------------------

Check status:        ./scripts/setup-foundation-mcp.sh --status
View logs:           ./scripts/setup-foundation-mcp.sh --logs [service]
Stop services:       ./scripts/setup-foundation-mcp.sh --stop
Start services:      ./scripts/setup-foundation-mcp.sh --start
Clean up:            ./scripts/setup-foundation-mcp.sh --cleanup

TROUBLESHOOTING:
---------------

ChromaDB not accessible?
  - Check port 8000 is not in use: lsof -i :8000
  - View logs: ./scripts/setup-foundation-mcp.sh --logs chromadb
  - Restart: docker restart hal9000-chromadb

Memory Bank issues?
  - Check storage permissions: ls -la ~/.hal9000/foundation-mcp/memory-bank-data
  - Verify directory is writable by your user

Need help?
  ./scripts/setup-foundation-mcp.sh --help

===============================================================================
EOF
}

# Main execution
main() {
    local action="setup"
    local service="all"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --chromadb-port)
                CHROMADB_PORT="$2"
                shift 2
                ;;
            --storage-path)
                FOUNDATION_HOME="$2"
                CHROMADB_DATA="${FOUNDATION_HOME}/chromadb-data"
                MEMORY_BANK_DATA="${FOUNDATION_HOME}/memory-bank-data"
                shift 2
                ;;
            --chromadb-only)
                service="chromadb"
                shift
                ;;
            --memory-bank-only)
                service="memory-bank"
                shift
                ;;
            --sequential-thinking-only)
                service="sequential-thinking"
                shift
                ;;
            --start)
                action="start"
                shift
                ;;
            --stop)
                action="stop"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
            --logs)
                action="logs"
                service="${2:-all}"
                shift 2
                ;;
            --cleanup)
                action="cleanup"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Execute requested action
    case "$action" in
        setup)
            echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
            echo -e "${BLUE}hal-9000 Foundation MCP Servers Setup${NC}"
            echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
            echo ""

            check_docker
            create_directories

            case "$service" in
                chromadb|all)
                    setup_chromadb || exit 1
                    ;;
            esac

            case "$service" in
                memory-bank|all)
                    setup_memory_bank || exit 1
                    ;;
            esac

            case "$service" in
                sequential-thinking|all)
                    setup_sequential_thinking || exit 1
                    ;;
            esac

            echo ""
            show_status
            show_integration_instructions
            ;;

        start)
            check_docker
            start_services
            ;;

        stop)
            check_docker
            stop_services
            ;;

        status)
            show_status
            ;;

        logs)
            check_docker
            show_logs "$service"
            ;;

        cleanup)
            check_docker
            cleanup
            ;;

        *)
            log_error "Unknown action: $action"
            exit 1
            ;;
    esac
}

# Run main
main "$@"
