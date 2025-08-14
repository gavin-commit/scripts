#!/bin/bash

# Claude Code Setup Script
# Automates environment configuration for LiteLLM and certificate handling

set -e

osascript -e 'display notification "Starting Claude Code setup..." with title "Claude Code Setup"'

# Configuration - hardcoded for JAMF deployment
LITELLM_BASE_URL="https://litellm.aitooling.mgsops.net"
OTEL_ENDPOINT="http://10.75.11.46:4317"

# Step 1: Get API key from user
API_KEY=$(osascript -e 'Tell application "System Events" to display dialog "Enter your API key for Claude Code setup:" default answer "" with hidden answer with title "Claude Code Setup"' -e 'text returned of result' 2>/dev/null)

if [ -z "$API_KEY" ]; then
    osascript -e 'display dialog "Error: API key cannot be empty" with title "Claude Code Setup" buttons {"OK"} default button "OK"'
    exit 1
fi

# Step 2: Export system certificates
osascript -e 'display notification "Exporting system certificates..." with title "Claude Code Setup"'
security find-certificate -a -p > ~/node_ca_bundle.pem
osascript -e 'display notification "✓ Certificates exported" with title "Claude Code Setup"'

# Step 3: Set up environment variables for current session
osascript -e 'display notification "Setting up environment variables..." with title "Claude Code Setup"'
export ANTHROPIC_BASE_URL="$LITELLM_BASE_URL"
export ANTHROPIC_AUTH_TOKEN="$API_KEY"
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT="$OTEL_ENDPOINT"
export OTEL_RESOURCE_ATTRIBUTES=host.name=$HOSTNAME,user.id=$USER
export NODE_EXTRA_CA_CERTS="$HOME/node_ca_bundle.pem"
osascript -e 'display notification "✓ Environment variables set" with title "Claude Code Setup"'

# Step 4: Test the configuration
osascript -e 'display notification "Testing HTTPS connection..." with title "Claude Code Setup"'
node -e "
console.log('Testing HTTPS connection...');
const https = require('https');
https.get('$LITELLM_BASE_URL', (res) => {
  console.log('Success! Status:', res.statusCode);
  process.exit(0);
}).on('error', (err) => {
  console.error('Error:', err.message);
  process.exit(1);
});
"
echo

# Step 5: Make configuration permanent
osascript -e 'display notification "Making configuration permanent..." with title "Claude Code Setup"'

# Detect shell
if [[ $SHELL == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ $SHELL == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
else
    osascript -e 'display notification "Warning: Unknown shell. Using .zshrc as default." with title "Claude Code Setup"'
    SHELL_RC="$HOME/.zshrc"
fi

osascript -e 'display notification "Adding configuration to shell profile..." with title "Claude Code Setup"'

# Add configuration to shell profile
cat >> "$SHELL_RC" << EOF

# Claude Code Configuration (added by setup script)
export ANTHROPIC_BASE_URL="$LITELLM_BASE_URL"
export ANTHROPIC_AUTH_TOKEN="$API_KEY"
export NODE_EXTRA_CA_CERTS="\$HOME/node_ca_bundle.pem"
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT="$OTEL_ENDPOINT"
export OTEL_RESOURCE_ATTRIBUTES=host.name=\$HOSTNAME,user.id=\$USER
EOF

osascript -e 'display dialog "Setup Complete!

Configuration has been saved to your shell profile.

To use in new terminal sessions:
1. Open a new terminal window/tab, or
2. Run: source '$SHELL_RC'

Your API key and certificates are now configured for Claude Code." with title "Claude Code Setup" buttons {"OK"} default button "OK"'