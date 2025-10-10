#!/bin/bash
# Local Wazuh Rules Testing Script
# Tests custom decoders and rules using Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DECODER_DIR="${SCRIPT_DIR}/config/decoders"
RULES_DIR="${SCRIPT_DIR}/config/rules"
TEST_LOGS_DIR="${SCRIPT_DIR}/test-logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "Wazuh Rules Testing Environment"
echo -e "==========================================${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${NC}"
    exit 1
fi

# Function to run wazuh-logtest
run_logtest() {
    local test_file=$1
    local container_name="wazuh-logtest-temp"
    
    echo -e "${BLUE}🧪 Testing: $(basename "$test_file")${NC}"
    
    # Run temporary Wazuh Manager container with custom decoders/rules
    docker run --rm -i \
        --name "$container_name" \
        -v "${DECODER_DIR}:/var/ossec/etc/decoders:ro" \
        -v "${RULES_DIR}:/var/ossec/etc/rules:ro" \
        wazuh/wazuh-manager:4.13.1 \
        /var/ossec/bin/wazuh-logtest < "$test_file"
}

# Function to validate decoder/rule syntax
validate_syntax() {
    local container_name="wazuh-validate-temp"
    
    echo -e "${BLUE}🔍 Validating decoder and rule syntax...${NC}"
    
    docker run --rm \
        --name "$container_name" \
        -v "${DECODER_DIR}:/var/ossec/etc/decoders:ro" \
        -v "${RULES_DIR}:/var/ossec/etc/rules:ro" \
        wazuh/wazuh-manager:4.13.1 \
        /var/ossec/bin/wazuh-logtest -t
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Syntax validation passed${NC}"
    else
        echo -e "${RED}❌ Syntax validation failed${NC}"
        exit 1
    fi
}

# Function to run interactive mode
interactive_mode() {
    local container_name="wazuh-logtest-interactive"
    
    echo -e "${BLUE}🎮 Starting interactive mode...${NC}"
    echo -e "${YELLOW}Paste your JSON logs (one per line)${NC}"
    echo -e "${YELLOW}Press Ctrl+D when done${NC}"
    echo ""
    
    docker run --rm -it \
        --name "$container_name" \
        -v "${DECODER_DIR}:/var/ossec/etc/decoders:ro" \
        -v "${RULES_DIR}:/var/ossec/etc/rules:ro" \
        wazuh/wazuh-manager:4.13.1 \
        /var/ossec/bin/wazuh-logtest
}

# Main menu
case "${1:-menu}" in
    validate)
        validate_syntax
        ;;
    
    test)
        if [ -z "$2" ]; then
            echo -e "${RED}❌ Please specify a test file${NC}"
            echo "Usage: $0 test <test-file>"
            exit 1
        fi
        
        if [ ! -f "$2" ]; then
            echo -e "${RED}❌ Test file not found: $2${NC}"
            exit 1
        fi
        
        validate_syntax
        echo ""
        run_logtest "$2"
        ;;
    
    test-all)
        validate_syntax
        echo ""
        
        if [ ! -d "$TEST_LOGS_DIR" ]; then
            echo -e "${YELLOW}⚠️  No test-logs directory found${NC}"
            exit 0
        fi
        
        for test_file in "$TEST_LOGS_DIR"/*.txt; do
            if [ -f "$test_file" ]; then
                echo ""
                run_logtest "$test_file"
                echo ""
            fi
        done
        ;;
    
    interactive)
        validate_syntax
        echo ""
        interactive_mode
        ;;
    
    quick)
        # Quick test with sample log
        echo -e "${BLUE}🚀 Quick test with sample MikroTik log${NC}"
        echo ""
        
        echo '{"log_source":"mikrotik","vendor":"mikrotik","product":"routeros","hostname":"192.168.1.1","timestamp":"2025-10-10T19:00:00.000Z","full_message":"login failure for user admin from 192.168.1.100 via ssh","parsed":{"user":"admin","src_ip":"192.168.1.100","protocol":"ssh"}}' | \
        docker run --rm -i \
            -v "${DECODER_DIR}:/var/ossec/etc/decoders:ro" \
            -v "${RULES_DIR}:/var/ossec/etc/rules:ro" \
            wazuh/wazuh-manager:4.13.1 \
            /var/ossec/bin/wazuh-logtest
        ;;
    
    menu|*)
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  validate           - Validate decoder and rule syntax"
        echo "  test <file>        - Test specific log file"
        echo "  test-all           - Test all files in test-logs/"
        echo "  interactive        - Start interactive testing mode"
        echo "  quick              - Quick test with sample log"
        echo ""
        echo "Examples:"
        echo "  $0 validate"
        echo "  $0 test test-logs/mikrotik-samples.txt"
        echo "  $0 test-all"
        echo "  $0 interactive"
        echo "  $0 quick"
        echo ""
        echo "Directory structure:"
        echo "  config/decoders/   - Custom decoders"
        echo "  config/rules/      - Custom rules"
        echo "  test-logs/         - Test log files"
        ;;
esac
