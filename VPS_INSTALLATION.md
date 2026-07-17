# Claude Code VPS Installation Guide

This guide provides step-by-step instructions for installing and configuring Claude Code on a VPS (Virtual Private Server).

## Prerequisites

- VPS running Linux (Ubuntu 20.04+, Debian 11+, CentOS 7+, or similar)
- Root or sudo access
- Internet connectivity
- 2GB+ RAM recommended
- 1GB+ free disk space

## Quick Start

```bash
# Clone and run the VPS installation script
git clone https://github.com/babamongo/claude-red.git
cd claude-red
./install-vps.sh --install-all
```

## Detailed Installation

### 1. System Preparation

Update system packages:
```bash
sudo apt-get update && sudo apt-get upgrade -y  # Debian/Ubuntu
# or
sudo yum update -y  # CentOS/RHEL
```

### 2. Install Claude Code CLI

#### Option A: Using npm (Recommended)

```bash
# Install Node.js 18+ (if not already installed)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code
```

#### Option B: Using Homebrew (macOS on VPS)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install claude-code
```

#### Option C: Manual Binary Installation

```bash
# Download the latest release
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
RELEASE=$(curl -s https://api.github.com/repos/anthropics/claude-code/releases/latest | grep tag_name | cut -d'"' -f4)

wget "https://github.com/anthropics/claude-code/releases/download/${RELEASE}/claude-code-${RELEASE}-${OS}-${ARCH}.tar.gz"
tar -xzf claude-code-*.tar.gz
sudo mv claude-code /usr/local/bin/
```

### 3. Configure Claude Code

Initialize Claude Code configuration:

```bash
# Set up API key (required for Claude functionality)
export ANTHROPIC_API_KEY="your-api-key-here"

# Or save it to ~/.claude/config.json
mkdir -p ~/.claude
cat > ~/.claude/config.json << EOF
{
  "api_key": "your-api-key-here",
  "model": "claude-3-5-sonnet",
  "temperature": 0.7
}
EOF

# Set appropriate permissions
chmod 600 ~/.claude/config.json
```

### 4. Install Claude-Red Skills

Install offensive security skills:

```bash
cd ~/claude-red
# Install all skills
./install.sh --target ~/.claude/skills/claude-red

# Or install specific category
./install.sh --target ~/.claude/skills/claude-red --category web
```

Available categories:
- `web` - Web application security
- `auth` - Authentication & identity
- `active-directory` - Active Directory
- `wireless` - Wireless security
- `cloud` - Cloud security
- `infrastructure` - Infrastructure & red team
- `exploit-dev` - Exploit development
- `fuzzing` - Fuzzing & vulnerability research
- `recon` - Reconnaissance

### 5. Verify Installation

```bash
# Check Claude Code version
claude --version

# Test API connectivity
claude --test

# Verify skills are loaded
ls -la ~/.claude/skills/claude-red/
```

## Running Claude Code on VPS

### Interactive Mode

```bash
# Start Claude Code interactive session
claude

# Or with specific project directory
claude --project /path/to/project
```

### Batch/Script Mode

```bash
# Process a file through Claude
cat requirements.txt | claude --system-file - < input.md

# Run in non-interactive mode
echo "Analyze this code" | claude --stdin --model claude-3-5-sonnet
```

### Background/Detached Execution

For long-running tasks on VPS:

```bash
# Use nohup for persistent execution
nohup claude --project /path/to/project > claude.log 2>&1 &

# Or use tmux/screen for session management
tmux new-session -d -s claude-work
tmux send-keys -t claude-work "cd /path/to/project && claude" Enter
```

## VPS-Specific Configuration

### Running as a Systemd Service

Create a systemd service for Claude Code:

```bash
sudo tee /etc/systemd/system/claude-code.service > /dev/null << EOF
[Unit]
Description=Claude Code Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/projects
Environment="ANTHROPIC_API_KEY=your-api-key-here"
ExecStart=/usr/local/bin/claude --daemon
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable claude-code
sudo systemctl start claude-code
sudo systemctl status claude-code
```

### Docker Installation (Optional)

If you prefer containerized deployment:

```bash
# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM node:18-alpine

RUN npm install -g @anthropic-ai/claude-code

WORKDIR /work
ENV ANTHROPIC_API_KEY=""

ENTRYPOINT ["claude"]
EOF

# Build and run
docker build -t claude-code .
docker run -it --rm \
  -e ANTHROPIC_API_KEY="your-key" \
  -v $(pwd):/work \
  claude-code
```

### Environment Setup

Create a startup script for reproducible environments:

```bash
#!/bin/bash
# ~/.claude/vps-setup.sh

# Load environment
export ANTHROPIC_API_KEY="$(cat ~/.claude/api-key)"
export CLAUDE_HOME="$HOME/.claude"
export CLAUDE_SKILLS="$CLAUDE_HOME/skills"

# Set up aliases for convenience
alias cw='claude --project'
alias ctest='claude --test'

# Ensure skills are up to date
test -d "$CLAUDE_SKILLS/claude-red" || {
  git clone https://github.com/babamongo/claude-red "$CLAUDE_SKILLS/claude-red"
}

echo "Claude Code environment ready"
```

Make it executable and source on login:
```bash
chmod +x ~/.claude/vps-setup.sh
echo 'source ~/.claude/vps-setup.sh' >> ~/.bashrc
source ~/.bashrc
```

## Troubleshooting

### API Key Issues

```bash
# Verify API key is set
echo $ANTHROPIC_API_KEY

# Test connectivity
curl -s https://api.anthropic.com/v1/models \
  -H "x-api-key: $ANTHROPIC_API_KEY" | head -20
```

### Skills Not Loading

```bash
# Check skills directory
ls -la ~/.claude/skills/

# Rebuild skills cache
rm -rf ~/.claude/.cache
claude --reload-skills

# Verify skill files
find ~/.claude/skills -name "SKILL.md" | wc -l
```

### Memory Issues

If VPS runs out of memory:

```bash
# Check memory usage
free -h

# Increase swap (if needed)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make swap permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Advanced: Multi-User Setup

For shared VPS environments:

```bash
# Create dedicated user
sudo useradd -m -s /bin/bash claude-user
sudo su - claude-user

# Install Claude Code for specific user
npm install -g @anthropic-ai/claude-code

# Set up user-specific configuration
mkdir -p ~/.claude/skills
# ... configure API key in ~/.claude/config.json
```

## Security Considerations

1. **API Key Management**
   - Never commit `.claude/config.json` to version control
   - Use environment variables: `export ANTHROPIC_API_KEY="..."`
   - Set restricted file permissions: `chmod 600 ~/.claude/config.json`

2. **Network Security**
   - Use SSH for remote VPS access
   - Consider VPN for additional security
   - Firewall Claude Code daemon if needed

3. **Resource Limits**
   - Monitor disk space (especially `/home` partition)
   - Set memory limits for Claude processes if shared
   - Use rate limiting for API calls if applicable

## Performance Optimization

```bash
# VPS system optimization for Claude Code
cat > /etc/sysctl.d/99-claude-code.conf << EOF
# Increase file descriptor limits
fs.file-max = 2097152
fs.nr_open = 2097152

# Optimize network
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
EOF

sudo sysctl -p /etc/sysctl.d/99-claude-code.conf
```

## Updating Claude Code

```bash
# Update to latest version
npm update -g @anthropic-ai/claude-code

# Or reinstall specific version
npm install -g @anthropic-ai/claude-code@<version>

# Verify update
claude --version
```

## Uninstallation

```bash
# Remove Claude Code
npm uninstall -g @anthropic-ai/claude-code

# Clean up configuration
rm -rf ~/.claude

# Remove systemd service (if installed)
sudo systemctl stop claude-code
sudo systemctl disable claude-code
sudo rm /etc/systemd/system/claude-code.service
sudo systemctl daemon-reload
```

## Support & Resources

- Claude Code CLI: https://code.claude.com
- Claude API Docs: https://docs.anthropic.com
- Claude-Red Repository: https://github.com/babamongo/claude-red
- Issues: https://github.com/babamongo/claude-red/issues

## Version Info

- Last Updated: 2026-07-17
- Tested With: Ubuntu 20.04+, Node.js 18+, Claude Code 1.0+
