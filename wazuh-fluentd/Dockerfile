# Wazuh Fluentd Docker Image
# Multi-source syslog collector with OpenSearch integration
# Version: 2.0 - Refactored modular architecture
FROM fluent/fluentd:v1.17-debian-1

# Switch to root to install plugins
USER root

# Install system dependencies for plugins
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    ruby-dev \
    && rm -rf /var/lib/apt/lists/*

# Install required plugins
RUN gem install fluent-plugin-opensearch -v 1.1.4 --no-document && \
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
# 30514 - MikroTik (UDP)
# 30515 - Fortigate CEF (TCP)
# 30516 - Fortigate Syslog (UDP)
# 30517 - Cisco ASA (UDP)
# 30518 - Palo Alto (TCP)
# 30519 - Generic Syslog (UDP)
# 30520 - Generic Syslog (TCP)
# 30521 - Generic CEF (TCP)
# 30522 - Generic CEF (UDP)
# 30523 - Ruckus Wireless (UDP)
# 30524 - Ruckus Wireless (TCP)
# 30525 - Check Point CEF (TCP)
# 30526 - Check Point Syslog (UDP)
EXPOSE 2055/udp 6343/udp 30514/udp 30515/tcp 30516/udp 30517/udp 30518/tcp 30519/udp 30520/tcp 30521/tcp 30522/udp 30523/udp 30524/tcp 30525/tcp 30526/udp

# Switch back to fluent user
USER fluent

# Set environment variables
ENV FLUENTD_CONF=/fluentd/etc/fluent.conf

# Run configuration script and start fluentd
CMD ["/bin/sh", "-c", "/usr/local/bin/config.sh && exec fluentd -c /fluentd/etc/fluent.conf"]
