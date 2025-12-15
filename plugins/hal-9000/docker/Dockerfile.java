# HAL-9000 Java Profile
# Extends base image with GraalVM JDK 23 + native-image
#
# Build: docker build -f docker/Dockerfile.java -t ghcr.io/hellblazer/hal-9000:java .
# Publish: docker push ghcr.io/hellblazer/hal-9000:java

FROM ghcr.io/hellblazer/hal-9000:latest

LABEL profile="java"
LABEL description="Java development with Claude CLI, GraalVM 23, native-image, Maven, Gradle"

# Install dependencies for GraalVM native-image
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    build-essential \
    libz-dev \
    zlib1g-dev \
    maven \
    && rm -rf /var/lib/apt/lists/*

# Install GraalVM JDK 23 (includes native-image)
# Using Oracle GraalVM which bundles native-image
ARG GRAALVM_VERSION=23.0.1
ARG TARGETARCH
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x64") && \
    wget -q https://download.oracle.com/graalvm/23/latest/graalvm-jdk-23_linux-${ARCH}_bin.tar.gz -O /tmp/graalvm.tar.gz && \
    mkdir -p /opt/graalvm && \
    tar -xzf /tmp/graalvm.tar.gz -C /opt/graalvm --strip-components=1 && \
    rm /tmp/graalvm.tar.gz

# Set environment
ENV GRAALVM_HOME=/opt/graalvm
ENV JAVA_HOME=/opt/graalvm
ENV PATH="${GRAALVM_HOME}/bin:${PATH}"

# Install Gradle 8.11 (latest stable)
RUN curl -fsSL https://services.gradle.org/distributions/gradle-8.11-bin.zip -o /tmp/gradle.zip \
    && unzip /tmp/gradle.zip -d /opt \
    && ln -s /opt/gradle-8.11/bin/gradle /usr/local/bin/gradle \
    && rm /tmp/gradle.zip

# Verify installation
RUN echo "Java tools:" \
    && java -version \
    && native-image --version \
    && mvn --version \
    && gradle --version

# Inherit CMD from base (runs setup.sh then bash)
