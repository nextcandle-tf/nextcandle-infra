#!/bin/bash
# scripts/setup-runner.sh

echo "=== GitHub Action Multi-Runner Setup ==="
echo "Please obtain the Token from: Settings -> Actions -> Runners -> New self-hosted runner"
echo ""

# Default Repository URL
DEFAULT_REPO_URL="https://github.com/ikpark09/candle-pattern-finder"

read -p "Enter Repository URL (Default: $DEFAULT_REPO_URL): " INPUT_REPO_URL
REPO_URL=${INPUT_REPO_URL:-$DEFAULT_REPO_URL}

read -p "Enter Runner Token: " RUNNER_TOKEN
read -p "Enter Number of Runners to Setup (Default: 1): " INPUT_RUNNER_COUNT
RUNNER_COUNT=${INPUT_RUNNER_COUNT:-1}

# Architecture determination
case $(uname -m) in aarch64) ARCH="arm64" ;; amd64|x86_64) ARCH="x64" ;; *) echo "Unsupported architecture"; exit 1 ;; esac
RUNNER_PKG="actions-runner-linux-${ARCH}-2.321.0.tar.gz"

echo "Downloading runner package..."
curl -o $RUNNER_PKG -L https://github.com/actions/runner/releases/download/v2.321.0/$RUNNER_PKG

HOST_NAME=$(hostname)

for (( i=1; i<=RUNNER_COUNT; i++ ))
do
    RUNNER_DIR="actions-runner-$i"
    RUNNER_NAME="${HOST_NAME}-${i}"
    
    echo "------------------------------------------------"
    echo "Setting up Runner #$i: $RUNNER_NAME in $RUNNER_DIR"
    
    mkdir -p $RUNNER_DIR
    
    # Extract
    tar xzf ./$RUNNER_PKG -C $RUNNER_DIR
    
    cd $RUNNER_DIR
    
    # Configure
    # Check if already configured
    if [ -f ".runner" ]; then
        echo "Runner already configured in $RUNNER_DIR. Skipping configuration."
    else
        echo "Configuring runner..."
        ./config.sh --url $REPO_URL --token $RUNNER_TOKEN --name $RUNNER_NAME --unattended --replace
    fi
    
    # Install and Start Service
    echo "Installing service..."
    sudo ./svc.sh install
    sudo ./svc.sh start
    
    cd ..
    echo "✅ Runner #$i setup complete!"
done

echo ""
echo "🎉 All $RUNNER_COUNT runners have been installed and started."
rm -f $RUNNER_PKG

