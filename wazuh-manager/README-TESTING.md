# Local Rules Testing with Docker

Test your custom Wazuh decoders and rules locally before deploying to production.

## Quick Start

```bash
# Validate syntax
./test-rules.sh validate

# Quick test with sample log
./test-rules.sh quick

# Test all sample logs
./test-rules.sh test-all

# Interactive mode
./test-rules.sh interactive
```

## Directory Structure

```
wazuh-manager/
├── config/
│   ├── decoders/
│   │   ├── mikrotik-json-decoder.xml
│   │   └── esxi-json-decoder.xml
│   └── rules/
│       ├── mikrotik-rules.xml
│       └── esxi-rules.xml
├── test-logs/
│   ├── mikrotik-samples.txt
│   └── esxi-samples.txt
├── test-rules.sh              # Testing script
└── README-TESTING.md          # This file
```

## Commands

### Validate Syntax

Check if decoders and rules have valid XML syntax:

```bash
./test-rules.sh validate
```

**Output:**
```
🔍 Validating decoder and rule syntax...
✅ Syntax validation passed
```

### Quick Test

Run a quick test with a sample MikroTik login failure:

```bash
./test-rules.sh quick
```

**Output:**
```
**Phase 1: Completed pre-decoding.
**Phase 2: Completed decoding.
       name: 'mikrotik-json'
       mikrotik.log_source: 'mikrotik'
       mikrotik.parsed.user: 'admin'
       mikrotik.parsed.src_ip: '192.168.1.100'
       ...
**Phase 3: Completed filtering (rules).
       id: '100011'
       level: '5'
       description: 'MikroTik: Login failure...'
**Alert to be generated.
```

### Test Specific File

Test a specific log file:

```bash
./test-rules.sh test test-logs/mikrotik-samples.txt
```

### Test All Files

Test all files in `test-logs/` directory:

```bash
./test-rules.sh test-all
```

This will run through:
- `mikrotik-samples.txt` (8 test cases)
- `esxi-samples.txt` (10 test cases)

### Interactive Mode

Start interactive testing mode where you can paste logs manually:

```bash
./test-rules.sh interactive
```

Then paste your JSON logs (one per line) and press `Ctrl+D` when done.

## Creating Test Files

### Format

Test files should contain one JSON log per line:

```
{"log_source":"mikrotik","full_message":"login failure..."}
{"log_source":"mikrotik","full_message":"user logged in..."}
```

### Example: Create Custom Test

```bash
cat > test-logs/my-test.txt << 'EOF'
{"log_source":"mikrotik","full_message":"login failure for user admin from 192.168.1.100 via ssh","parsed":{"user":"admin","src_ip":"192.168.1.100","protocol":"ssh"}}
{"log_source":"mikrotik","full_message":"user admin logged in from 192.168.1.100 via ssh","parsed":{"user":"admin","src_ip":"192.168.1.100","protocol":"ssh"}}
EOF

# Test it
./test-rules.sh test test-logs/my-test.txt
```

## Understanding Output

### Phase 1: Pre-decoding

```
**Phase 1: Completed pre-decoding.
```

Basic log parsing completed. If this fails, check log format.

### Phase 2: Decoding

```
**Phase 2: Completed decoding.
       name: 'mikrotik-json'
       mikrotik.log_source: 'mikrotik'
       mikrotik.vendor: 'mikrotik'
       mikrotik.parsed.user: 'admin'
       mikrotik.parsed.src_ip: '192.168.1.100'
```

Shows:
- **name**: Which decoder matched
- **Fields**: All extracted dynamic fields

✅ **Success**: Custom decoder name appears (`mikrotik-json`)
❌ **Problem**: Generic decoder (`json`) - check prematch pattern

### Phase 3: Rule Matching

```
**Phase 3: Completed filtering (rules).
       id: '100011'
       level: '5'
       description: 'MikroTik: Login failure for user admin from 192.168.1.100 via ssh'
       groups: '['mikrotik', 'syslog', 'authentication']'
       firedtimes: '1'
       mail: 'False'
**Alert to be generated.
```

Shows:
- **id**: Rule ID that matched
- **level**: Alert severity (0-15)
- **description**: Alert message
- **groups**: Rule categories

✅ **Success**: "Alert to be generated" appears
❌ **Problem**: No rule matched - check field names in rules

## Troubleshooting

### Decoder Not Matching

**Problem:**
```
**Phase 2: Completed decoding.
       name: 'json'  # Generic decoder, not custom
```

**Solutions:**

1. **Check prematch pattern:**
   ```xml
   <decoder name="mikrotik-json">
     <prematch>^{.*"log_source"\s*:\s*"mikrotik"</prematch>
   </decoder>
   ```

2. **Verify JSON format:**
   ```bash
   # Validate JSON
   echo '{"log_source":"mikrotik"}' | jq .
   ```

3. **Check field exists:**
   ```bash
   echo '{"log_source":"mikrotik"}' | jq '.log_source'
   ```

### Fields Not Extracted

**Problem:**
```
**Phase 2: Completed decoding.
       name: 'mikrotik-json'
       # No fields shown
```

**Solutions:**

1. **Ensure JSON is single-line** (no newlines)
2. **Validate JSON syntax** with `jq`
3. **Check for special characters** that need escaping

### Rule Not Matching

**Problem:**
```
**Phase 3: Completed filtering (rules).
       # No rule matched
```

**Solutions:**

1. **Check field names match decoder output:**
   ```xml
   <!-- Decoder output shows: mikrotik.full_message -->
   <!-- Rule must use: -->
   <field name="mikrotik.full_message">login failure</field>
   ```

2. **Verify regex pattern:**
   ```xml
   <!-- Use exact match or regex -->
   <field name="mikrotik.full_message">login failure</field>
   <!-- OR -->
   <field name="mikrotik.full_message" type="pcre2">login.*failure</field>
   ```

3. **Check parent rule:**
   ```xml
   <rule id="100011" level="5">
     <if_sid>100001</if_sid>  <!-- Must match parent -->
     ...
   </rule>
   ```

### Wrong Alert Level

**Problem:**
Alert level doesn't match expectations.

**Solution:**
Adjust in rule XML:
```xml
<rule id="100011" level="5">  <!-- Change level here -->
```

Levels:
- **0-3**: Info (no alert generated by default)
- **4-7**: Low-Medium
- **8-11**: High
- **12-15**: Critical

## Sample Test Cases

### MikroTik Tests

**Login Failure (Level 5):**
```json
{"log_source":"mikrotik","full_message":"login failure for user admin from 192.168.1.100 via ssh","parsed":{"user":"admin","src_ip":"192.168.1.100","protocol":"ssh"}}
```

**User Logged In (Level 3):**
```json
{"log_source":"mikrotik","full_message":"user admin logged in from 192.168.1.100 via ssh","parsed":{"user":"admin","src_ip":"192.168.1.100","protocol":"ssh"}}
```

**Firewall Rule Change (Level 8):**
```json
{"log_source":"mikrotik","full_message":"filter rule added by admin from 192.168.1.100","parsed":{"user":"admin","src_ip":"192.168.1.100"}}
```

**User Added (Level 8):**
```json
{"log_source":"mikrotik","full_message":"user testuser added by admin","parsed":{"user":"testuser"}}
```

**Rogue DHCP (Level 3):**
```json
{"log_source":"mikrotik","full_message":"dhcp alert on bridge: discovered unknown dhcp server, mac 00:11:22:33:44:55, ip 192.168.1.200","parsed":{"src_ip":"192.168.1.200"}}
```

### ESXi Tests

**SSH Login Failure (Level 5):**
```json
{"log_source":"vmware-esxi","full_message":"SSH login has failed for 'root@10.0.0.50'","parsed":{"esxi_host":"esxi-host01","user":"root","srcip":"10.0.0.50"}}
```

**VM Created (Level 5):**
```json
{"log_source":"vmware-esxi","full_message":"Created virtual machine new-vm on esxi-host01","parsed":{"esxi_host":"esxi-host01","vm":"new-vm"}}
```

**Account Created (Level 8):**
```json
{"log_source":"vmware-esxi","full_message":"Account testuser was created on host esxi-host01","parsed":{"esxi_host":"esxi-host01","user":"testuser"}}
```

**File Deletion (Level 6):**
```json
{"log_source":"vmware-esxi","full_message":"Deletion of file or directory /tmp/test.log from disk1 was initiated","parsed":{"esxi_host":"esxi-host01","path":"/tmp/test.log","disk":"disk1"}}
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Test Wazuh Rules

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Validate Rules
        run: |
          cd wazuh-manager
          ./test-rules.sh validate
      
      - name: Test All Logs
        run: |
          cd wazuh-manager
          ./test-rules.sh test-all
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

cd wazuh-manager
./test-rules.sh validate

if [ $? -ne 0 ]; then
    echo "❌ Rule validation failed"
    exit 1
fi

echo "✅ Rules validated successfully"
```

## Best Practices

1. **Test Before Deploy**
   - Always run `./test-rules.sh validate` before committing
   - Test with realistic log samples

2. **Version Control**
   - Keep test files in Git
   - Document expected behavior in comments

3. **Comprehensive Coverage**
   - Test all rule conditions
   - Include edge cases
   - Test both positive and negative cases

4. **Continuous Testing**
   - Add new test cases when adding rules
   - Run tests in CI/CD pipeline

5. **Document Changes**
   - Update test files when changing rules
   - Add comments explaining test purpose

## Advanced Usage

### Test with Verbose Output

```bash
docker run --rm -i \
  -v "$(pwd)/config/decoders:/var/ossec/etc/decoders:ro" \
  -v "$(pwd)/config/rules:/var/ossec/etc/rules:ro" \
  wazuh/wazuh-manager:4.13.1 \
  /var/ossec/bin/wazuh-logtest -v < test-logs/mikrotik-samples.txt
```

### Test Specific Rule ID

```bash
# Test and grep for specific rule
./test-rules.sh test test-logs/mikrotik-samples.txt | grep "id: '100011'"
```

### Export Test Results

```bash
# Save results to file
./test-rules.sh test-all > test-results-$(date +%Y%m%d).txt

# Compare with previous results
diff test-results-old.txt test-results-new.txt
```

## Resources

- [Wazuh Testing Documentation](https://documentation.wazuh.com/current/user-manual/ruleset/testing.html)
- [JSON Decoder Documentation](https://documentation.wazuh.com/current/user-manual/ruleset/decoders/json-decoder.html)
- [Rule Syntax Reference](https://documentation.wazuh.com/current/user-manual/ruleset/rules/index.html)
- [Dynamic Fields](https://documentation.wazuh.com/current/user-manual/ruleset/decoders/dynamic-fields.html)
