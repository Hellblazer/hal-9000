# Shell Script Tests (bats)

This directory contains bats (Bash Automated Testing System) tests for shell scripts.

## Prerequisites

Install bats:

```bash
# macOS
brew install bats-core

# Ubuntu/Debian
apt-get install bats

# From source
git clone https://github.com/bats-core/bats-core.git
./bats-core/install.sh /usr/local
```

## Running Tests

From the repository root:

```bash
# Run all bats tests
bats plugins/hal-9000/tests/bats/

# Run specific test file
bats plugins/hal-9000/tests/bats/container-common.bats

# Run with verbose output
bats --verbose-run plugins/hal-9000/tests/bats/

# Run with timing information
bats --timing plugins/hal-9000/tests/bats/
```

## Test Files

- `container-common.bats` - Tests for lib/container-common.sh shared library

## Writing New Tests

Use the standard bats format:

```bash
@test "description of what is being tested" {
    # Setup
    local test_var="value"

    # Execute
    run some_function "$test_var"

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected"* ]]
}
```

### Common Assertions

```bash
# Exit status
[ "$status" -eq 0 ]    # Success
[ "$status" -ne 0 ]    # Failure

# Output matching
[[ "$output" == *"substring"* ]]    # Contains
[[ "$output" == "exact match" ]]    # Exact

# File existence
[ -f "$file" ]    # File exists
[ -d "$dir" ]     # Directory exists
[ ! -f "$file" ]  # File does not exist

# Variable checking
[ -n "$var" ]     # Not empty
[ -z "$var" ]     # Empty
```

### Setup and Teardown

```bash
setup() {
    # Runs before each test
    TEST_TMP_DIR="$(mktemp -d)"
}

teardown() {
    # Runs after each test
    rm -rf "$TEST_TMP_DIR"
}

setup_file() {
    # Runs once before all tests in file
}

teardown_file() {
    # Runs once after all tests in file
}
```

## CI Integration

To run in CI, add to your workflow:

```yaml
- name: Install bats
  run: |
    git clone https://github.com/bats-core/bats-core.git
    ./bats-core/install.sh $HOME/.local

- name: Run shell tests
  run: |
    $HOME/.local/bin/bats plugins/hal-9000/tests/bats/
```
