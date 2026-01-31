#!/bin/bash
set -e

REPO="Comquister/ConqPing"
APP_NAME="conqping"
INSTALL_DIR="$HOME/.local/bin"

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux*)     OS_TYPE="linux";;
    Darwin*)    OS_TYPE="macos";;
    *)          echo "Unsupported OS: $OS"; exit 1;;
esac

# Detect Architecture
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) ARCH_TYPE="x64";;
    aarch64|arm64) ARCH_TYPE="arm64";;
    i386|i686) ARCH_TYPE="x86";;
    *) echo "Unsupported Architecture: $ARCH"; exit 1;;
esac

BINARY_NAME="conqping-${OS_TYPE}-${ARCH_TYPE}"
URL="https://github.com/$REPO/releases/latest/download/$BINARY_NAME"

echo "Detected OS: $OS_TYPE"
echo "Detected Architecture: $ARCH_TYPE"
echo "Downloading $APP_NAME from $URL..."

# Create Install Directory
mkdir -p "$INSTALL_DIR"

# Download
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$INSTALL_DIR/$APP_NAME"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$URL" -O "$INSTALL_DIR/$APP_NAME"
else
    echo "Error: curl or wget is required to install."
    exit 1
fi

chmod +x "$INSTALL_DIR/$APP_NAME"
echo "Installed to $INSTALL_DIR/$APP_NAME"

# Add to PATH if not present
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "Adding $INSTALL_DIR to PATH..."
    SHELL_NAME=$(basename "$SHELL")
    RC_FILE=""
    
    if [ "$SHELL_NAME" = "bash" ]; then
        RC_FILE="$HOME/.bashrc"
    elif [ "$SHELL_NAME" = "zsh" ]; then
        RC_FILE="$HOME/.zshrc"
    elif [ "$SHELL_NAME" = "fish" ]; then
        RC_FILE="$HOME/.config/fish/config.fish"
    fi

    if [ -n "$RC_FILE" ]; then
        if [ "$SHELL_NAME" = "fish" ]; then
             echo "set -U fish_user_paths $INSTALL_DIR \$fish_user_paths" >> "$RC_FILE"
        else
            echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$RC_FILE"
        fi
        echo "Added to $RC_FILE. Please restart your terminal or run: source $RC_FILE"
    else
        echo "Could not detect shell configuration file. Please manually add $INSTALL_DIR to your PATH."
    fi
else
    echo "$INSTALL_DIR is already in PATH."
fi

echo "Installation Complete! You can now run '$APP_NAME <IP>'"
echo "Example: $APP_NAME 8.8.8.8"
