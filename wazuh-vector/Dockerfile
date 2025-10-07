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

# Create necessary directories (as root, will set permissions later)
RUN mkdir -p /vector/config \
    /vector/data \
    /vector/pipelines

# Copy configuration files
COPY config/vector.toml /vector/config/vector.toml
COPY config/pipelines/ /vector/pipelines/
COPY config/config.sh /usr/local/bin/
COPY config/setup_pipelines.sh /usr/local/bin/

# Make scripts executable
RUN chmod +x /usr/local/bin/config.sh \
    /usr/local/bin/setup_pipelines.sh

# Set proper permissions (check if vector user exists, if not use root)
RUN if id vector >/dev/null 2>&1; then \
        chown -R vector:vector /vector; \
    else \
        echo "Vector user not found, using root permissions"; \
    fi

# Expose ports for different sources
# 2055 - NetFlow (UDP)
# 40514 - MikroTik (UDP)
# 40519 - Generic Syslog (UDP)
# 40520 - Generic Syslog (TCP)
EXPOSE 2055/udp 40514/udp 40519/udp 40520/tcp

# Switch to vector user if it exists, otherwise stay as root
RUN if id vector >/dev/null 2>&1; then \
        echo "Switching to vector user"; \
    else \
        echo "Vector user not found, will run as root"; \
    fi

USER vector

# Set environment variables
ENV VECTOR_CONFIG=/vector/config/vector.toml

# Run configuration script and start vector
CMD ["/bin/sh", "-c", "/usr/local/bin/config.sh && exec vector --config /vector/config/vector.toml"]
