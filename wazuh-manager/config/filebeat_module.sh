## variables
REPOSITORY="packages-dev.wazuh.com/pre-release"
WAZUH_TAG=$(curl --silent https://api.github.com/repos/wazuh/wazuh/git/refs/tags | grep '["]ref["]:' | sed -E 's/.*\"([^\"]+)\".*/\1/'  | cut -c 11- | grep ^v${WAZUH_VERSION}$)

## check tag to use the correct repository
if [[ -n "${WAZUH_TAG}" ]]; then
  REPOSITORY="packages.wazuh.com/4.x"
fi

curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/${FILEBEAT_CHANNEL}-${FILEBEAT_VERSION}-x86_64.rpm &&\
yum install -y ${FILEBEAT_CHANNEL}-${FILEBEAT_VERSION}-x86_64.rpm && rm -f ${FILEBEAT_CHANNEL}-${FILEBEAT_VERSION}-x86_64.rpm && \
echo "Downloading Wazuh filebeat module from: https://${REPOSITORY}/filebeat/${WAZUH_FILEBEAT_MODULE}" && \
curl -s https://${REPOSITORY}/filebeat/${WAZUH_FILEBEAT_MODULE} -o /tmp/wazuh-filebeat-module.tar.gz && \
file /tmp/wazuh-filebeat-module.tar.gz && \
if file /tmp/wazuh-filebeat-module.tar.gz | grep -q gzip; then \
    tar -xvz -C /usr/share/filebeat/module -f /tmp/wazuh-filebeat-module.tar.gz && rm /tmp/wazuh-filebeat-module.tar.gz; \
else \
    echo "ERROR: Downloaded file is not a valid gzip archive" && cat /tmp/wazuh-filebeat-module.tar.gz && exit 1; \
fi