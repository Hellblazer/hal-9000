# HAL-9000 Java Profile
# Extends base image with Java development tools
#
# Build: docker build -f docker/Dockerfile.java -t ghcr.io/hellblazer/hal-9000:java .
# Publish: docker push ghcr.io/hellblazer/hal-9000:java

FROM ghcr.io/hellblazer/hal-9000:latest

LABEL profile="java"
LABEL description="Java development with Claude CLI, JDK 21, Maven, Gradle"

# Install Java 21 (LTS) and Maven
RUN apt-get update && apt-get install -y \
    openjdk-21-jdk \
    maven \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Gradle
RUN curl -fsSL https://services.gradle.org/distributions/gradle-8.5-bin.zip -o /tmp/gradle.zip \
    && unzip /tmp/gradle.zip -d /opt \
    && ln -s /opt/gradle-8.5/bin/gradle /usr/local/bin/gradle \
    && rm /tmp/gradle.zip

# Set JAVA_HOME - create architecture-independent symlink
RUN JAVA_DIR=$(ls -d /usr/lib/jvm/java-21-openjdk-* 2>/dev/null | head -1) && \
    ln -sf "$JAVA_DIR" /usr/lib/jvm/java-21-openjdk && \
    echo "JAVA_HOME=/usr/lib/jvm/java-21-openjdk" >> /etc/environment
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Verify installation
RUN echo "Java tools:" \
    && java -version \
    && mvn --version \
    && gradle --version

# Inherit CMD from base (runs setup.sh then bash)
