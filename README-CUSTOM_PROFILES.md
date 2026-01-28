# Creating Custom Profiles for hal-9000

This guide explains how to create and use custom Docker profiles for hal-9000. Profiles are specialized Docker images that bundle hal-9000 with additional development tools.

## What is a Profile?

A profile is a Docker image variant of hal-9000 pre-configured with specific tools and dependencies for a programming language or framework.

**Built-in Profiles:**
- `base` - Claude CLI, Docker CLI, Python 3, Node.js 20 LTS, MCP servers
- `python` - base + Python 3.11, uv, pandas, numpy, scikit-learn
- `node` - base + Node.js tools, npm packages, TypeScript
- `java` - base + GraalVM JDK 25, Maven 3.9, Gradle 8.11

**Custom Profiles** can add:
- Language runtimes (Ruby, Go, Rust, PHP, etc.)
- Framework tools (Rails, Django, FastAPI, Spring Boot, etc.)
- Domain-specific tools (Kubernetes, Terraform, QEMU, etc.)
- Custom build systems and package managers
- Specialized development environments

## Architecture

```
hal-9000
├── plugins/hal-9000/docker/
│   ├── Dockerfile.hal9000        # Base image (Claude + Node + Python + Docker)
│   ├── Dockerfile.python         # Extends base with Python tools
│   ├── Dockerfile.node           # Extends base with Node.js tools
│   ├── Dockerfile.java           # Extends base with Java/GraalVM
│   └── Dockerfile.custom-ruby    # Your custom profile (example)
├── Makefile                      # Build commands
├── hal-9000                      # Main script (auto-detects profile)
└── .claude-plugin/
    └── marketplace.json          # Lists available profiles
```

**Key Design:**
- All profiles extend `base` which has Claude, Docker, Python, Node.js, and MCP servers
- Profiles are built as Docker image tags: `ghcr.io/hellblazer/hal-9000:base`, `:python`, `:ruby`
- `hal-9000` script auto-detects project type and uses appropriate profile
- Users can override with `--profile` flag

## Step-by-Step: Create a Custom Profile

### Step 1: Create a Dockerfile for Your Profile

Create `plugins/hal-9000/docker/Dockerfile.custom-ruby`:

```dockerfile
# HAL-9000 Ruby Profile
# Extends base image with Ruby, Rails, and related tools
#
# Build: docker build -f docker/Dockerfile.custom-ruby -t ghcr.io/hellblazer/hal-9000:ruby .
# Publish: docker push ghcr.io/hellblazer/hal-9000:ruby

FROM ghcr.io/hellblazer/hal-9000:base

LABEL profile="ruby"
LABEL description="Ruby development with Claude CLI, Ruby 3.3, Rails, Bundler"

# Install Ruby dependencies
RUN apt-get update && apt-get install -y \
    ruby-full \
    ruby-dev \
    build-essential \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Ruby Gems
RUN gem install bundler rails puma

# Verify installation
RUN echo "Ruby tools:" \
    && ruby --version \
    && rails --version \
    && bundle --version

# Inherit CMD from base
```

**Key Points:**
- Use `FROM ghcr.io/hellblazer/hal-9000:base` to inherit Claude, Docker, Node.js, Python
- Add `LABEL profile="ruby"` for identification
- Install only the extra tools needed (don't duplicate base layer content)
- Include verification step to ensure tools work
- Don't override CMD (inherit from base)

### Step 2: Add Build Target to Makefile

Edit `Makefile` and update the `build` target:

```makefile
# Around line 253, change:
build: build-base build-python build-node build-java
# To:
build: build-base build-python build-node build-java build-ruby
```

Then add the new build target (after line 295):

```makefile
build-ruby:
	@echo "$(YELLOW)Building Ruby image...$(NC)"
	$(QUIET)docker build \
		-f $(PLUGIN_DIR)/docker/Dockerfile.custom-ruby \
		-t $(IMAGE_BASE):ruby \
		--label version="$(VERSION)" \
		.
	@echo "$(GREEN)✓ Ruby image built$(NC)"
```

Add to `.PHONY` declaration (line 391):

```makefile
.PHONY: help clean clean-build clean-test clean-containers clean-docker-images
.PHONY: build build-base build-python build-node build-java build-ruby
```

### Step 3: Update hal-9000 Script to Auto-Detect Your Profile

Edit `hal-9000` and find the `detect_profile()` function (around line 828):

```bash
detect_profile() {
    local target_dir="${1:-.}"

    # Check for Java project
    if [[ -f "$target_dir/pom.xml" ]] || [[ -f "$target_dir/build.gradle" ]] || [[ -f "$target_dir/build.gradle.kts" ]]; then
        echo "java"
        return 0
    fi

    # Check for Python project
    if [[ -f "$target_dir/pyproject.toml" ]] || [[ -f "$target_dir/Pipfile" ]] || [[ -f "$target_dir/requirements.txt" ]]; then
        echo "python"
        return 0
    fi

    # Check for Node.js project
    if [[ -f "$target_dir/package.json" ]]; then
        echo "node"
        return 0
    fi

    # YOUR CUSTOM PROFILE: Check for Ruby project
    if [[ -f "$target_dir/Gemfile" ]] || [[ -f "$target_dir/Rakefile" ]] || [[ -d "$target_dir/app" ]]; then
        echo "ruby"
        return 0
    fi

    # Default to base
    echo "$DEFAULT_PROFILE"
}
```

**Detection Logic:**
- Check for project files that uniquely identify the project type
- Ruby: `Gemfile` (Bundler), `Rakefile` (Rake tasks), `app/` directory (Rails)
- Go: `go.mod`, `main.go`
- Rust: `Cargo.toml`
- PHP: `composer.json`, `index.php`
- .NET: `*.csproj`, `*.sln`
- Return the profile name (lowercase, matches Docker tag)

### Step 4: Build and Test Your Profile

```bash
# Build the Ruby profile
make build-ruby

# Test by launching a Ruby project
cd /path/to/ruby/project
hal-9000
# Should show: "Auto-detected profile: ruby"
# Should launch with Ruby tools available

# Verify Ruby is available
ruby --version
rails --version
```

### Step 5: Test Auto-Detection

Create a test directory with a Gemfile:

```bash
mkdir -p /tmp/test-ruby-project
cd /tmp/test-ruby-project
echo "source 'https://rubygems.org'" > Gemfile
echo "gem 'rails'" >> Gemfile

# Launch hal-9000
hal-9000
# Should auto-detect as ruby profile
```

### Step 6: Document Your Profile

Create `plugins/hal-9000/docker/README-RUBY.md`:

```markdown
# Ruby Profile for hal-9000

Claude Code with Ruby 3.3, Rails, and related development tools.

## What's Included

- Ruby 3.3
- Bundler (Ruby dependency manager)
- Rails 7.x (latest)
- Puma (Rails default server)
- All base tools: Claude CLI, Docker, Node.js, Python, MCP servers

## Auto-Detection

The Ruby profile is automatically selected for projects with:
- `Gemfile` (Bundler configuration)
- `Rakefile` (Rake task runner)
- `app/` directory (Rails project structure)

## Manual Selection

```bash
hal-9000 --profile ruby /path/to/project
```

## Usage Examples

### Start a new Rails project

```bash
hal-9000 /path/to/myapp
# Inside Claude:
rails new . --skip-bundle
bundle install
./bin/dev
```

### Work with existing Rails project

```bash
cd /path/to/existing/rails/app
hal-9000
# Inside Claude:
bundle install
rails server
```

### Generate Rails scaffolding

```bash
rails generate scaffold Post title:string content:text
rails db:migrate
```

## Performance Notes

- Ruby 3.3 compilation: ~30 seconds on first container start
- Rails startup: ~2-3 seconds
- Bundle install with many gems: depends on gem count

## Custom Tools

To add more Ruby tools to this profile, edit `plugins/hal-9000/docker/Dockerfile.custom-ruby` and add to the `gem install` line:

```dockerfile
RUN gem install bundler rails puma rspec rubocop
```

Then rebuild:

```bash
make build-ruby
```
```

## Publishing Your Profile

### Local Development

Users can build your profile locally:

```bash
# In hal-9000 repository
make build-ruby
hal-9000 /my/ruby/project
```

### Share as Fork

```bash
# Fork the repository
git clone https://github.com/yourname/hal-9000
cd hal-9000

# Create your profile (steps 1-4 above)
make build-ruby

# Push to your fork
git push origin main
```

### Submit as Pull Request

1. Fork `hellblazer/hal-9000`
2. Create profile following steps 1-6
3. Test thoroughly
4. Submit PR with:
   - Dockerfile for new profile
   - Makefile updates
   - hal-9000 script updates
   - Documentation (README-PROFILE.md)
   - Test evidence (screenshots/logs)

### Public Docker Registry

If you want to publish your own:

```bash
# Build with your registry
docker build \
  -f plugins/hal-9000/docker/Dockerfile.custom-ruby \
  -t yourregistry/hal-9000:ruby \
  .

# Push to your registry
docker push yourregistry/hal-9000:ruby

# Users can then use:
# (requires modifying CONTAINER_IMAGE_BASE in hal-9000 script)
```

## Examples: Custom Profiles

### Go Profile

```dockerfile
FROM ghcr.io/hellblazer/hal-9000:base

LABEL profile="go"
LABEL description="Go development with Claude CLI, Go 1.23, air, golangci-lint"

RUN apt-get update && apt-get install -y \
    golang-go \
    && rm -rf /var/lib/apt/lists/*

RUN go install github.com/cosmtrek/air@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

**In `detect_profile()`:**
```bash
if [[ -f "$target_dir/go.mod" ]] || [[ -f "$target_dir/go.sum" ]]; then
    echo "go"
    return 0
fi
```

### Rust Profile

```dockerfile
FROM ghcr.io/hellblazer/hal-9000:base

LABEL profile="rust"
LABEL description="Rust development with Claude CLI, Rust, Cargo, clippy"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . /root/.cargo/env && \
    rustup component add clippy

ENV PATH="/root/.cargo/bin:${PATH}"
```

**In `detect_profile()`:**
```bash
if [[ -f "$target_dir/Cargo.toml" ]]; then
    echo "rust"
    return 0
fi
```

### PHP Profile

```dockerfile
FROM ghcr.io/hellblazer/hal-9000:base

LABEL profile="php"
LABEL description="PHP development with Claude CLI, PHP 8.3, Composer, Laravel"

RUN apt-get update && apt-get install -y \
    php \
    php-cli \
    php-dev \
    php-curl \
    php-mbstring \
    php-xml \
    && rm -rf /var/lib/apt/lists*

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
```

**In `detect_profile()`:**
```bash
if [[ -f "$target_dir/composer.json" ]]; then
    echo "php"
    return 0
fi
```

## Common Pitfalls

### ❌ Don't extend the wrong base

```dockerfile
# WRONG - extends Python profile directly
FROM ghcr.io/hellblazer/hal-9000:python

# RIGHT - extends base to get all dependencies
FROM ghcr.io/hellblazer/hal-9000:base
```

**Why:** Profiles are independent; if you extend `:python`, you won't get Node.js.

### ❌ Don't duplicate base layer content

```dockerfile
# WRONG - repeats base installations
RUN apt-get update && apt-get install -y python3 nodejs
RUN npm install -g @allpepper/memory-bank-mcp

# RIGHT - add only extra tools
RUN apt-get update && apt-get install -y ruby
RUN gem install rails
```

### ❌ Don't forget to verify installations

```dockerfile
# WRONG - no verification
RUN apt-get install -y golang

# RIGHT - verify it works
RUN apt-get install -y golang && \
    go version
```

### ❌ Don't override the CMD

```dockerfile
# WRONG - prevents claude from running
CMD ["bash"]

# RIGHT - inherit from base
# (no CMD statement = inherit from base)
```

### ❌ Don't forget auto-detection

```bash
# If you add a profile to Makefile but forget detect_profile(),
# users have to manually specify: hal-9000 --profile ruby
# This defeats the purpose of profiles!
```

## Naming Convention

- Profile name: lowercase, one word, language/framework name
- Docker file: `Dockerfile.custom-{name}` (e.g., `Dockerfile.custom-ruby`)
- Build target: `build-{name}` (e.g., `build-ruby`)
- Docker tag: `ghcr.io/hellblazer/hal-9000:{name}` (e.g., `hal-9000:ruby`)
- Detection file: Check for standard project files (Gemfile, go.mod, Cargo.toml, etc.)

## Troubleshooting

### Image not found when launching

```bash
# Make sure it's built
docker images | grep ruby
# If not present, build it:
make build-ruby
```

### Auto-detect not working

Check `detect_profile()` in hal-9000:
```bash
# Verify detection logic
grep -A20 "detect_profile()" hal-9000

# Test manually
./hal-9000 --verify /path/to/project
# Should show: "Auto-detected profile: ruby"
```

### Container starts but tools not available

```bash
# Verify the Dockerfile installed tools
docker run --rm ghcr.io/hellblazer/hal-9000:ruby ruby --version

# If error, check Dockerfile installation step
```

### Large image size

```bash
# Profile images can be 1-2 GB each due to tools
# This is expected and necessary for fast startup

# To reduce: Remove unnecessary tools from Dockerfile
# To verify: docker images | grep hal-9000
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Test Custom Profile
on: [push, pull_request]

jobs:
  test-profile:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build Ruby profile
        run: make build-ruby

      - name: Test profile
        run: |
          docker run --rm ghcr.io/hellblazer/hal-9000:ruby \
            ruby -e "puts 'Ruby works!'"

      - name: Publish (if main branch)
        if: github.ref == 'refs/heads/main'
        run: |
          docker push ghcr.io/hellblazer/hal-9000:ruby
```

## Contributing Your Profile

Community profiles are welcome! Submit a PR with:

1. ✅ Dockerfile for the profile
2. ✅ Makefile build target
3. ✅ `hal-9000` script detection logic
4. ✅ Documentation (README-{PROFILE}.md)
5. ✅ Test evidence
6. ✅ License agreement (Apache 2.0)

We'll review and merge quality profiles that:
- Extend `base` image correctly
- Have clear auto-detection logic
- Work reliably with Claude
- Are documented

---

**Questions?** See the main [README.md](README.md) or open an issue on GitHub.
