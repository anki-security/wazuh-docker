# Wazuh Vector Docker Image
# Multi-source syslog and NetFlow collector with OpenSearch integration
# Version: 3.0 - Migrated from Fluentd to Vector.dev for better performance
FROM timberio/vector:0.39.0-debian

# Switch to root for setup
USER root

# Install debugging tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    netcat-openbsd \
    dnsutils \
    iputils-ping \
    tcpdump \
    net-tools \
    iproute2 \
    lsof \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /vector/config \
    /vector/data \
    /vector/pipelines && \
    chown -R vector:vector /vector

# Copy configuration files
COPY config/vector.toml /vector/config/vector.toml
COPY config/pipelines/ /vector/pipelines/
COPY config/config.sh /usr/local/bin/
COPY config/setup_pipelines.sh /usr/local/bin/

# Make scripts executable
RUN chmod +x /usr/local/bin/config.sh \
    /usr/local/bin/setup_pipelines.sh

# Set proper permissions
RUN chown -R vector:vector /vector

# Expose ports for different sources
# 2055 - NetFlow (UDP)
# 40514 - MikroTik (UDP)
# 40519 - Generic Syslog (UDP)
# 40520 - Generic Syslog (TCP)
EXPOSE 2055/udp 40514/udp 40519/udp 40520/tcp

# Switch to vector user
USER vector

# Set environment variables
ENV VECTOR_CONFIG=/vector/config/vector.toml

# Run configuration script and start vector
CMD ["/bin/sh", "-c", "/usr/local/bin/config.sh && exec vector --config /vector/config/vector.toml"]
