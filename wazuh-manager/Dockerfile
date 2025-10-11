# Wazuh Docker Copyright (C) 2017, Wazuh Inc. (License GPLv2)
FROM amazonlinux:2023

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

ARG WAZUH_VERSION
ARG WAZUH_TAG_REVISION
ARG FILEBEAT_TEMPLATE_BRANCH
ARG FILEBEAT_CHANNEL=filebeat-oss
ARG FILEBEAT_VERSION=7.10.2
ARG WAZUH_FILEBEAT_MODULE
ARG S6_VERSION="v2.2.0.3"

RUN yum install curl-minimal xz gnupg tar gzip openssl findutils procps tcpdump net-tools -y &&\
    yum clean all

COPY config/check_repository.sh /
COPY config/filebeat_module.sh /
COPY config/permanent_data.env config/permanent_data.sh /

RUN chmod 775 /check_repository.sh
RUN source /check_repository.sh

RUN yum install wazuh-manager-${WAZUH_VERSION}-${WAZUH_TAG_REVISION} -y && \
    yum clean all && \
    chmod 775 /filebeat_module.sh && \
    source /filebeat_module.sh && \
    rm /filebeat_module.sh && \
    # Download s6-overlay with retry logic (GitHub releases can be flaky)
    SUCCESS=0 && \
    for i in 1 2 3; do \
        echo "Attempt $i to download s6-overlay..." && \
        curl --retry 3 --retry-delay 5 --retry-all-errors \
        -L https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-amd64.tar.gz \
        -o /tmp/s6-overlay-amd64.tar.gz && \
        if file /tmp/s6-overlay-amd64.tar.gz | grep -q gzip; then \
            SUCCESS=1 && break; \
        else \
            echo "Downloaded file is not gzip, retrying..." && rm -f /tmp/s6-overlay-amd64.tar.gz && sleep 10; \
        fi; \
    done && \
    if [ "$SUCCESS" -eq 0 ]; then echo "Failed to download s6-overlay after 3 attempts" && exit 1; fi && \
    tar xzf /tmp/s6-overlay-amd64.tar.gz -C / --exclude="./bin" && \
    tar xzf /tmp/s6-overlay-amd64.tar.gz -C /usr ./bin && \
    rm  /tmp/s6-overlay-amd64.tar.gz

COPY config/etc/ /etc/
COPY --chown=root:wazuh config/create_user.py /var/ossec/framework/scripts/create_user.py

# Copy custom rules and decoders
COPY --chown=root:wazuh config/rules/*.xml /var/ossec/etc/rules/
COPY --chown=root:wazuh config/decoders/*.xml /var/ossec/etc/decoders/

COPY config/filebeat.yml /etc/filebeat/

RUN chmod go-w /etc/filebeat/filebeat.yml

ADD https://raw.githubusercontent.com/wazuh/wazuh/$FILEBEAT_TEMPLATE_BRANCH/extensions/elasticsearch/7.x/wazuh-template.json /etc/filebeat
RUN chmod go-w /etc/filebeat/wazuh-template.json

# Prepare permanent data
# Sync calls are due to https://github.com/docker/docker/issues/9547

#Make mount directories for keep permissions

RUN mkdir -p /var/ossec/var/multigroups && \
    chown root:wazuh /var/ossec/var/multigroups && \
    chmod 770 /var/ossec/var/multigroups && \
    mkdir -p /var/ossec/agentless && \
    chown root:wazuh /var/ossec/agentless && \
    chmod 770 /var/ossec/agentless && \
    mkdir -p /var/ossec/active-response/bin && \
    chown root:wazuh /var/ossec/active-response/bin && \
    chmod 770 /var/ossec/active-response/bin && \
    chmod 755 /permanent_data.sh && \
    sync && /permanent_data.sh && \
    sync && rm /permanent_data.sh

RUN rm /etc/yum.repos.d/wazuh.repo

# Services ports
EXPOSE 55000/tcp 1514/tcp 1515/tcp 1516/tcp 1533/tcp

ENTRYPOINT [ "/init" ]
