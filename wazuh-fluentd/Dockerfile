# Wazuh Fluentd Docker Image
# Multi-source syslog collector with OpenSearch integration
# Version: 2.0 - Refactored modular architecture
FROM fluent/fluentd:v1.19-debian-1

# Switch to root to install plugins
USER root

# Install system dependencies for plugins and debugging tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    ruby-dev \
    curl \
    netcat-openbsd \
    dnsutils \
    iputils-ping \
    tcpdump \
    net-tools \
    iproute2 \
    lsof

# Install required plugins with cache mount
RUN --mount=type=cache,target=/root/.gem \
    gem install fluent-plugin-opensearch -v 1.1.4 --no-document && \
    gem install fluent-plugin-rewrite-tag-filter --no-document && \
    gem install fluent-plugin-record-modifier --no-document && \
    gem install fluent-plugin-grok-parser --no-document && \
    gem install fluent-plugin-parser-cri --no-document && \
    gem install fluent-plugin-multi-format-parser --no-document && \
    gem install fluent-plugin-detect-exceptions --no-document && \
    gem install fluent-plugin-prometheus --no-document && \
    gem install fluent-plugin-elasticsearch --no-document && \
    gem install fluent-plugin-netflowipfix --no-document && \
    gem sources --clear-all

# Create necessary directories
RUN mkdir -p /fluentd/etc/conf.d \
    /fluentd/buffer \
    /fluentd/log \
    /fluentd/failed_records \
    /fluentd/pipelines && \
    chown -R fluent:fluent /fluentd

# Copy configuration files
COPY config/fluent.conf /fluentd/etc/fluent.conf
COPY config/conf.d/ /fluentd/etc/conf.d/
COPY config/pipelines/ /fluentd/pipelines/
COPY config/config.sh /usr/local/bin/
COPY config/setup_pipelines.sh /usr/local/bin/

# Make scripts executable
RUN chmod +x /usr/local/bin/config.sh \
    /usr/local/bin/setup_pipelines.sh

# Set proper permissions
RUN chown -R fluent:fluent /fluentd/etc /fluentd/pipelines

# Expose ports for different syslog sources
# 2055 - NetFlow/IPFIX (UDP)
# 6343 - sFlow (UDP)
# 40514 - MikroTik (UDP)
# 40515 - Fortigate CEF (TCP)
# 40516 - Fortigate Syslog (UDP)
# 40517 - Cisco ASA (UDP)
# 40518 - Palo Alto (TCP)
# 40519 - Generic Syslog (UDP)
# 40520 - Generic Syslog (TCP)
# 40521 - Generic CEF (TCP)
# 40522 - Generic CEF (UDP)
# 40523 - Ruckus Wireless (UDP)
# 40524 - Ruckus Wireless (TCP)
# 40525 - Check Point CEF (TCP)
# 40526 - Check Point Syslog (UDP)
EXPOSE 2055/udp 6343/udp 40514/udp 40515/tcp 40516/udp 40517/udp 40518/tcp 40519/udp 40520/tcp 40521/tcp 40522/udp 40523/udp 40524/tcp 40525/tcp 40526/udp

# Switch back to fluent user
USER fluent

# Set environment variables
ENV FLUENTD_CONF=/fluentd/etc/fluent.conf

# Run configuration script and start fluentd
CMD ["/bin/sh", "-c", "/usr/local/bin/config.sh && exec fluentd -c /fluentd/etc/fluent.conf"]
