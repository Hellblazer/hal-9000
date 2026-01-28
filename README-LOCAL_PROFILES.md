# Local Profiles Quick Start

Zero friction custom profiles for hal-9000. Create a Docker image locally and hal-9000 uses it automatically.

## The Fastest Way

```bash
# 1. Create local profile directory
mkdir -p ~/.hal9000/profiles/ruby

# 2. Create Dockerfile (copy/paste below)
cat > ~/.hal9000/profiles/ruby/Dockerfile << 'EOF'
FROM ghcr.io/hellblazer/hal-9000:base

LABEL profile="ruby"
LABEL description="Ruby development with Rails"

RUN apt-get update && apt-get install -y ruby ruby-dev build-essential && \
    rm -rf /var/lib/apt/lists* && \
    gem install bundler rails puma

RUN ruby --version && rails --version
EOF

# 3. Use it (hal-9000 auto-detects and builds on first use)
cd /path/to/ruby/project
hal-9000
```

**That's it!** hal-9000 will:
1. Detect you're in a Ruby project (looks for `Gemfile`, `Rakefile`, etc.)
2. See that you have a local Ruby profile in `~/.hal9000/profiles/ruby/`
3. Build the profile automatically on first use
4. Launch Claude with Ruby tools available

## How It Works

```
Your Ruby Project (with Gemfile)
        ↓
hal-9000 script
        ↓
Detects Gemfile → knows profile should be "ruby"
        ↓
Checks ~/.hal9000/profiles/ruby/Dockerfile
        ↓
(First time only) Builds image as "hal-9000-local-ruby:latest"
        ↓
Launches Claude with your custom environment
```

## Management Commands

```bash
# List all local profiles
hal-9000 profiles

# Explicitly build a profile
hal-9000 profiles build ruby

# Use a specific profile
hal-9000 --profile ruby /path/to/project
```

## Complete Examples

### Ruby with Rails

```dockerfile
FROM ghcr.io/hellblazer/hal-9000:base

LABEL profile="ruby"
LABEL description="Ruby 3.3 + Rails development"

RUN apt-get update && apt-get install -y \
    ruby-full \
    ruby-dev \
    build-essential \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN gem install bundler rails puma rspec
```

### Go

```dockerfile
FROM ghcr.io/hellblazer/hal-9000:base

LABEL profile="go"
LABEL description="Go 1.23 development"

RUN apt-get update && apt-get install -y \
    golang-go \
    && rm -rf /var/lib/apt/lists*

RUN go install github.com/cosmtrek/air@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

### Rust

```dockerfile
FROM ghcr.io/hellblazer/hal-9000:base

LABEL profile="rust"
LABEL description="Rust development with cargo"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . /root/.cargo/env && \
    rustup component add clippy

ENV PATH="/root/.cargo/bin:${PATH}"
```

### PHP with Composer

```dockerfile
FROM ghcr.io/hellblazer/hal-9000:base

LABEL profile="php"
LABEL description="PHP 8.3 with Composer"

RUN apt-get update && apt-get install -y \
    php \
    php-cli \
    php-curl \
    php-mbstring \
    php-xml \
    && rm -rf /var/lib/apt/lists*

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
```

## Auto-Detection

hal-9000 automatically selects profiles based on project files:

| Profile | Auto-Detected By | Location |
|---------|------------------|----------|
| `python` | `requirements.txt`, `pyproject.toml`, `Pipfile` | `~/.hal9000/profiles/python/` |
| `node` | `package.json` | `~/.hal9000/profiles/node/` |
| `ruby` | `Gemfile`, `Rakefile`, `app/` | `~/.hal9000/profiles/ruby/` |
| `go` | `go.mod`, `go.sum` | `~/.hal9000/profiles/go/` |
| `rust` | `Cargo.toml` | `~/.hal9000/profiles/rust/` |
| `java` | `pom.xml`, `build.gradle` | (built-in, not local) |

**To add auto-detection for your profile**, include detection logic when contributing back.

## Configuration

### Override Registry

Use a custom Docker registry instead of ghcr.io:

```bash
# Via environment variable (temporary)
export HAL9000_CONTAINER_IMAGE_BASE="docker.io/myusername/hal-9000"
hal-9000 /project

# Via config file (persistent)
cat > ~/.hal9000/config << 'EOF'
CONTAINER_IMAGE_BASE="docker.io/myusername/hal-9000"
EOF
```

### Precedence

Environment variables override config file, which overrides defaults:

```
HAL9000_CONTAINER_IMAGE_BASE env var
        ↓ (if not set)
~/.hal9000/config setting
        ↓ (if not set)
ghcr.io/hellblazer/hal-9000 (default)
```

## Troubleshooting

### Profile not detected?

```bash
# List available local profiles
hal-9000 profiles

# Expected output:
# Local profiles available in ~/.hal9000/profiles:
#   ✓ ruby (built)
#   ○ go (not yet built)
```

### Build failed?

```bash
# Check Dockerfile syntax
docker build -f ~/.hal9000/profiles/ruby/Dockerfile ~/.hal9000/profiles/ruby/

# If build passes manually but hal-9000 fails:
# - Check file permissions: chmod 644 ~/.hal9000/profiles/ruby/Dockerfile
# - Check base image exists: docker pull ghcr.io/hellblazer/hal-9000:base
```

### Image not being used?

```bash
# Verify the profile image is built
docker images | grep "hal-9000-local"

# Force rebuild
hal-9000 profiles build ruby

# Then use it
cd /ruby/project
hal-9000
```

## Performance

First use of a profile:
- ~30-60 seconds (builds Docker image)

Subsequent uses:
- <1 second (image already built, just launches)

Image sizes:
- Base: ~2.5 GB
- With tools: +500MB-1GB depending on what's installed

## Tips

### Keep Dockerfiles Simple

```dockerfile
# GOOD: Minimal additions
FROM ghcr.io/hellblazer/hal-9000:base
RUN gem install rails

# AVOID: Redundant installations (already in base)
FROM ghcr.io/hellblazer/hal-9000:base
RUN apt-get install -y python3 nodejs npm  # Already in base!
```

### Always Verify Installation

```dockerfile
# GOOD: Verify tools work
RUN ruby --version && rails --version

# AVOID: No verification
RUN gem install rails
```

### Use Specific Versions When Possible

```dockerfile
# GOOD: Pinned versions
RUN gem install rails:7.0.4 bundler:2.3.26

# AVOID: Always latest (may break)
RUN gem install rails bundler
```

## Next Steps

- **Contributing**: Have a profile others would want? See [README-CUSTOM_PROFILES.md](README-CUSTOM_PROFILES.md) for submitting to the project
- **Advanced**: Build profiles into your own Docker registry for team sharing
- **CI/CD**: Integrate profile builds into your development workflow

---

**Questions?** See the full [Custom Profiles Guide](README-CUSTOM_PROFILES.md) or the main [README.md](README.md).
