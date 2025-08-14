#!/bin/bash

# Claude Code Setup Script
# Automates environment configuration for LiteLLM and certificate handling

set -e

echo "=== Claude Code Configuration Setup ==="
echo

# Step 1: Get API Key from user
read -p "Enter your API key: " -s API_KEY
echo
echo

if [ -z "$API_KEY" ]; then
    echo "Error: API key cannot be empty"
    exit 1
fi

# Step 2: Export system certificates
echo "Step 1: Exporting system certificates..."
security find-certificate -a -p > ~/node_ca_bundle.pem
echo "✓ Certificates exported to ~/node_ca_bundle.pem"
echo

# Step 3: Set up environment variables for current session
echo "Step 2: Setting up environment variables..."
export ANTHROPIC_BASE_URL=https://litellm.aitooling.mgsops.net
export ANTHROPIC_AUTH_TOKEN="$API_KEY"
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://10.75.11.46:4317
export OTEL_RESOURCE_ATTRIBUTES=host.name=$HOSTNAME,user.id=$USER
export NODE_EXTRA_CA_CERTS="$HOME/node_ca_bundle.pem"
echo "✓ Environment variables set for current session"
echo

# Step 4: Test the configuration
echo "Step 3: Testing HTTPS connection..."
node -e "
console.log('Testing HTTPS connection...');
const https = require('https');
https.get('https://litellm.aitooling.mgsops.net', (res) => {
  console.log('Success! Status:', res.statusCode);
  process.exit(0);
}).on('error', (err) => {
  console.error('Error:', err.message);
  process.exit(1);
});
"
echo

# Step 5: Make configuration permanent
echo "Step 4: Making configuration permanent..."

# Detect shell
if [[ $SHELL == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ $SHELL == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
else
    echo "Warning: Unknown shell. Using .zshrc as default."
    SHELL_RC="$HOME/.zshrc"
fi

echo "Adding configuration to $SHELL_RC..."

# Add configuration to shell profile
cat >> "$SHELL_RC" << EOF

# Claude Code Configuration (added by setup script)
export ANTHROPIC_BASE_URL=https://litellm.aitooling.mgsops.net
export ANTHROPIC_AUTH_TOKEN="$API_KEY"
export NODE_EXTRA_CA_CERTS="\$HOME/node_ca_bundle.pem"
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://10.75.11.46:4317
export OTEL_RESOURCE_ATTRIBUTES=host.name=\$HOSTNAME,user.id=\$USER
EOF

echo "✓ Configuration added to $SHELL_RC"
echo

echo "=== Setup Complete! ==="
echo "Configuration has been saved to your shell profile."
echo "To use in new terminal sessions, either:"
echo "1. Open a new terminal window/tab, or"
echo "2. Run: source $SHELL_RC"
echo
echo "Your API key and certificates are now configured for Claude Code."
echo "Reboot your Mac to complete this installation."