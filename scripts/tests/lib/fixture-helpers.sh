#!/bin/bash
#
# fixture-helpers.sh - Test fixture utilities for hal-9000 testing
#
# Provides functions for creating, managing, and cleaning up test fixtures
# (valid test data files like pom.xml, package.json, etc.)
#
# USAGE:
#   source /scripts/tests/lib/fixture-helpers.sh
#   create_java_project /tmp/test-project
#   create_python_project /tmp/test-project
#   create_node_project /tmp/test-project

set -Eeuo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Fixtures directory (where valid fixtures are stored)
if [[ -z "${FIXTURES_DIR:-}" ]]; then
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        FIXTURES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )/fixtures"
    else
        # Fallback if BASH_SOURCE[0] is not available
        FIXTURES_DIR=""
    fi
fi

#==============================================================================
# Fixture Loading Functions
#==============================================================================

# Set the fixtures directory explicitly
# Usage: set_fixtures_dir /path/to/fixtures
set_fixtures_dir() {
    local fixtures_path="${1:?Missing fixtures path}"
    if [[ ! -d "$fixtures_path" ]]; then
        echo -e "${RED}✗ Error: Fixtures directory not found: $fixtures_path${NC}" >&2
        return 1
    fi
    FIXTURES_DIR="$fixtures_path"
}

# Get path to a fixture file
# Usage: get_fixture_path FIXTURE_NAME
get_fixture_path() {
    local fixture_name="${1:?Missing FIXTURE_NAME}"

    # Check if FIXTURES_DIR is set and not empty
    if [[ -z "${FIXTURES_DIR:-}" ]]; then
        echo -e "${RED}✗ Error: FIXTURES_DIR not set${NC}" >&2
        echo -e "${RED}  Please set FIXTURES_DIR environment variable or call set_fixtures_dir${NC}" >&2
        echo -e "${RED}  Script location info: BASH_SOURCE[0]=${BASH_SOURCE[0]:-<not available>}${NC}" >&2
        return 1
    fi

    local fixture_file="$FIXTURES_DIR/$fixture_name"

    if [[ ! -f "$fixture_file" ]]; then
        echo -e "${RED}✗ Error: Fixture not found: $fixture_name${NC}" >&2
        echo -e "${RED}  Expected path: $fixture_file${NC}" >&2
        echo -e "${RED}  FIXTURES_DIR=${FIXTURES_DIR}${NC}" >&2
        return 1
    fi

    echo "$fixture_file"
}

# Copy fixture file to destination
# Usage: copy_fixture SOURCE_FIXTURE DEST_PATH
copy_fixture() {
    local source_fixture="${1:?Missing SOURCE_FIXTURE}"
    local dest_path="${2:?Missing DEST_PATH}"

    local source_file
    source_file=$(get_fixture_path "$source_fixture") || return 1

    if cp "$source_file" "$dest_path" 2>/dev/null; then
        echo -e "${GREEN}✓ Copied fixture: $source_fixture → $dest_path${NC}" >&2
        return 0
    else
        echo -e "${RED}✗ Failed to copy fixture: $source_fixture${NC}" >&2
        return 1
    fi
}

#==============================================================================
# Java Project Fixtures
#==============================================================================

# Create minimal Java project with Maven
# Usage: create_java_maven_project /path/to/project
create_java_maven_project() {
    local project_dir="${1:?Missing PROJECT_DIR}"

    echo -e "${BLUE}ℹ Creating Java/Maven project: $project_dir${NC}" >&2

    # Create directory
    mkdir -p "$project_dir"

    # Copy pom.xml
    if ! copy_fixture "pom.xml" "$project_dir/pom.xml"; then
        return 1
    fi

    # Create source directory
    mkdir -p "$project_dir/src/main/java/com/example"
    mkdir -p "$project_dir/src/test/java"

    # Create minimal Application.java
    cat > "$project_dir/src/main/java/com/example/Application.java" << 'JAVA'
package com.example;

public class Application {
    public static void main(String[] args) {
        System.out.println("HAL-9000 Test Application");
    }
}
JAVA

    echo -e "${GREEN}✓ Java/Maven project created: $project_dir${NC}" >&2
    return 0
}

# Create minimal Java project with Gradle
# Usage: create_java_gradle_project /path/to/project
create_java_gradle_project() {
    local project_dir="${1:?Missing PROJECT_DIR}"

    echo -e "${BLUE}ℹ Creating Java/Gradle project: $project_dir${NC}" >&2

    # Create directory
    mkdir -p "$project_dir"

    # Copy build.gradle
    if ! copy_fixture "build.gradle" "$project_dir/build.gradle"; then
        return 1
    fi

    # Create source directory
    mkdir -p "$project_dir/src/main/java/com/example"
    mkdir -p "$project_dir/src/test/java"

    # Create gradle wrapper files (minimal)
    mkdir -p "$project_dir/gradle/wrapper"
    touch "$project_dir/gradle/wrapper/gradle-wrapper.properties"

    # Create Application.java
    cat > "$project_dir/src/main/java/com/example/Application.java" << 'JAVA'
package com.example;

public class Application {
    public static void main(String[] args) {
        System.out.println("HAL-9000 Test Application");
    }
}
JAVA

    echo -e "${GREEN}✓ Java/Gradle project created: $project_dir${NC}" >&2
    return 0
}

# Create minimal Java project with Gradle Kotlin
# Usage: create_java_gradle_kotlin_project /path/to/project
create_java_gradle_kotlin_project() {
    local project_dir="${1:?Missing PROJECT_DIR}"

    echo -e "${BLUE}ℹ Creating Java/Gradle Kotlin project: $project_dir${NC}" >&2

    # Create directory
    mkdir -p "$project_dir"

    # Copy build.gradle.kts
    if ! copy_fixture "build.gradle.kts" "$project_dir/build.gradle.kts"; then
        return 1
    fi

    # Create source directory
    mkdir -p "$project_dir/src/main/java/com/example"
    mkdir -p "$project_dir/src/test/java"

    # Create gradle wrapper files (minimal)
    mkdir -p "$project_dir/gradle/wrapper"
    touch "$project_dir/gradle/wrapper/gradle-wrapper.properties"

    # Create Application.java
    cat > "$project_dir/src/main/java/com/example/Application.java" << 'JAVA'
package com.example;

public class Application {
    public static void main(String[] args) {
        System.out.println("HAL-9000 Test Application");
    }
}
JAVA

    echo -e "${GREEN}✓ Java/Gradle Kotlin project created: $project_dir${NC}" >&2
    return 0
}

#==============================================================================
# Python Project Fixtures
#==============================================================================

# Create minimal Python project with requirements.txt
# Usage: create_python_requirements_project /path/to/project
create_python_requirements_project() {
    local project_dir="${1:?Missing PROJECT_DIR}"

    echo -e "${BLUE}ℹ Creating Python/requirements.txt project: $project_dir${NC}" >&2

    # Create directory
    mkdir -p "$project_dir"

    # Copy requirements.txt
    if ! copy_fixture "requirements.txt" "$project_dir/requirements.txt"; then
        return 1
    fi

    # Create source directory
    mkdir -p "$project_dir/src"

    # Create minimal __init__.py
    cat > "$project_dir/src/__init__.py" << 'PYTHON'
"""HAL-9000 Test Application"""
__version__ = "1.0.0"
PYTHON

    # Create minimal main.py
    cat > "$project_dir/src/main.py" << 'PYTHON'
#!/usr/bin/env python3
"""HAL-9000 Test Application"""

def main():
    print("HAL-9000 Test Application")

if __name__ == "__main__":
    main()
PYTHON

    echo -e "${GREEN}✓ Python/requirements.txt project created: $project_dir${NC}" >&2
    return 0
}

# Create minimal Python project with pyproject.toml
# Usage: create_python_pyproject_project /path/to/project
create_python_pyproject_project() {
    local project_dir="${1:?Missing PROJECT_DIR}"

    echo -e "${BLUE}ℹ Creating Python/pyproject.toml project: $project_dir${NC}" >&2

    # Create directory
    mkdir -p "$project_dir"

    # Copy pyproject.toml
    if ! copy_fixture "pyproject.toml" "$project_dir/pyproject.toml"; then
        return 1
    fi

    # Create source directory
    mkdir -p "$project_dir/hal9000_test"

    # Create minimal __init__.py
    cat > "$project_dir/hal9000_test/__init__.py" << 'PYTHON'
"""HAL-9000 Test Application"""
__version__ = "1.0.0"
PYTHON

    # Create minimal main.py
    cat > "$project_dir/hal9000_test/main.py" << 'PYTHON'
#!/usr/bin/env python3
"""HAL-9000 Test Application"""

def main():
    print("HAL-9000 Test Application")

if __name__ == "__main__":
    main()
PYTHON

    echo -e "${GREEN}✓ Python/pyproject.toml project created: $project_dir${NC}" >&2
    return 0
}

# Create minimal Python project with Pipfile
# Usage: create_python_pipfile_project /path/to/project
create_python_pipfile_project() {
    local project_dir="${1:?Missing PROJECT_DIR}"

    echo -e "${BLUE}ℹ Creating Python/Pipfile project: $project_dir${NC}" >&2

    # Create directory
    mkdir -p "$project_dir"

    # Copy Pipfile
    if ! copy_fixture "Pipfile" "$project_dir/Pipfile"; then
        return 1
    fi

    # Create source directory
    mkdir -p "$project_dir/app"

    # Create minimal __init__.py
    cat > "$project_dir/app/__init__.py" << 'PYTHON'
"""HAL-9000 Test Application"""
__version__ = "1.0.0"
PYTHON

    # Create minimal main.py
    cat > "$project_dir/app/main.py" << 'PYTHON'
#!/usr/bin/env python3
"""HAL-9000 Test Application"""

def main():
    print("HAL-9000 Test Application")

if __name__ == "__main__":
    main()
PYTHON

    echo -e "${GREEN}✓ Python/Pipfile project created: $project_dir${NC}" >&2
    return 0
}

#==============================================================================
# Node.js Project Fixtures
#==============================================================================

# Create minimal Node.js project
# Usage: create_node_project /path/to/project
create_node_project() {
    local project_dir="${1:?Missing PROJECT_DIR}"

    echo -e "${BLUE}ℹ Creating Node.js project: $project_dir${NC}" >&2

    # Create directory
    mkdir -p "$project_dir"

    # Copy package.json
    if ! copy_fixture "package.json" "$project_dir/package.json"; then
        return 1
    fi

    # Create source directory
    mkdir -p "$project_dir/src"

    # Create minimal index.js
    cat > "$project_dir/src/index.js" << 'JAVASCRIPT'
#!/usr/bin/env node
/**
 * HAL-9000 Test Application
 */

console.log("HAL-9000 Test Application");
JAVASCRIPT

    echo -e "${GREEN}✓ Node.js project created: $project_dir${NC}" >&2
    return 0
}

#==============================================================================
# Environment Variable Fixtures
#==============================================================================

# Create a .env fixture file with test variables
# Usage: create_env_file /path/to/.env
create_env_file() {
    local env_file="${1:?Missing ENV_FILE}"

    echo -e "${BLUE}ℹ Creating .env file: $env_file${NC}" >&2

    cat > "$env_file" << 'ENV'
# HAL-9000 Test Environment Variables

# Application
APP_NAME=hal-9000-test
APP_ENV=test
DEBUG=true

# API Configuration
API_KEY=sk-ant-test-key-12345678901234567890
API_TIMEOUT=30
API_RETRIES=3

# Database (if needed)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=test_db
DB_USER=test_user
DB_PASSWORD=test_password

# Claude Configuration
CLAUDE_API_KEY=sk-ant-test-claude-key
ANTHROPIC_API_KEY=sk-ant-test-anthropic-key

# Logging
LOG_LEVEL=debug
LOG_FILE=/tmp/test.log

# Feature Flags
FEATURE_NEW_API=true
FEATURE_BETA=false
ENV

    echo -e "${GREEN}✓ .env file created: $env_file${NC}" >&2
    return 0
}

#==============================================================================
# Configuration File Fixtures
#==============================================================================

# Create a config.json fixture
# Usage: create_config_json /path/to/config.json
create_config_json() {
    local config_file="${1:?Missing CONFIG_FILE}"

    echo -e "${BLUE}ℹ Creating config.json: $config_file${NC}" >&2

    cat > "$config_file" << 'JSON'
{
  "app": {
    "name": "hal-9000-test",
    "version": "1.0.0",
    "environment": "test"
  },
  "api": {
    "baseUrl": "http://localhost:8080",
    "timeout": 30,
    "retries": 3
  },
  "logging": {
    "level": "debug",
    "format": "json",
    "output": "stdout"
  },
  "features": {
    "newApi": true,
    "betaFeatures": false,
    "debugMode": true
  }
}
JSON

    echo -e "${GREEN}✓ config.json created: $config_file${NC}" >&2
    return 0
}

# Create a YAML configuration fixture
# Usage: create_config_yaml /path/to/config.yaml
create_config_yaml() {
    local config_file="${1:?Missing CONFIG_FILE}"

    echo -e "${BLUE}ℹ Creating config.yaml: $config_file${NC}" >&2

    cat > "$config_file" << 'YAML'
app:
  name: hal-9000-test
  version: 1.0.0
  environment: test

api:
  baseUrl: http://localhost:8080
  timeout: 30
  retries: 3

logging:
  level: debug
  format: json
  output: stdout

features:
  newApi: true
  betaFeatures: false
  debugMode: true
YAML

    echo -e "${GREEN}✓ config.yaml created: $config_file${NC}" >&2
    return 0
}

#==============================================================================
# Validation Functions
#==============================================================================

# Validate that a project structure is correct
# Usage: validate_project_structure PROJECT_TYPE PROJECT_DIR
validate_project_structure() {
    local project_type="${1:?Missing PROJECT_TYPE}"
    local project_dir="${2:?Missing PROJECT_DIR}"

    echo -e "${BLUE}ℹ Validating $project_type project: $project_dir${NC}" >&2

    case "$project_type" in
        java-maven)
            [[ -f "$project_dir/pom.xml" ]] || return 1
            [[ -d "$project_dir/src/main/java" ]] || return 1
            echo -e "${GREEN}✓ Java/Maven project valid${NC}" >&2
            ;;
        java-gradle)
            [[ -f "$project_dir/build.gradle" ]] || return 1
            [[ -d "$project_dir/src/main/java" ]] || return 1
            echo -e "${GREEN}✓ Java/Gradle project valid${NC}" >&2
            ;;
        python-requirements)
            [[ -f "$project_dir/requirements.txt" ]] || return 1
            echo -e "${GREEN}✓ Python/requirements.txt project valid${NC}" >&2
            ;;
        python-pyproject)
            [[ -f "$project_dir/pyproject.toml" ]] || return 1
            echo -e "${GREEN}✓ Python/pyproject.toml project valid${NC}" >&2
            ;;
        node)
            [[ -f "$project_dir/package.json" ]] || return 1
            [[ -d "$project_dir/src" ]] || return 1
            echo -e "${GREEN}✓ Node.js project valid${NC}" >&2
            ;;
        *)
            echo -e "${RED}✗ Unknown project type: $project_type${NC}" >&2
            return 1
            ;;
    esac

    return 0
}

#==============================================================================
# Cleanup
#==============================================================================

# Remove a test project fixture
# Usage: cleanup_project /path/to/project
cleanup_project() {
    local project_dir="${1:?Missing PROJECT_DIR}"

    if [[ -d "$project_dir" ]]; then
        rm -rf "$project_dir"
        echo -e "${GREEN}✓ Cleaned up project: $project_dir${NC}" >&2
    fi
}

#==============================================================================
# Export Functions
#==============================================================================

export -f set_fixtures_dir
export -f get_fixture_path
export -f copy_fixture
export -f create_java_maven_project
export -f create_java_gradle_project
export -f create_java_gradle_kotlin_project
export -f create_python_requirements_project
export -f create_python_pyproject_project
export -f create_python_pipfile_project
export -f create_node_project
export -f create_env_file
export -f create_config_json
export -f create_config_yaml
export -f validate_project_structure
export -f cleanup_project
