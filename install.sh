#!/bin/bash
set -e

REPO="Comquister/ConqPing"
APP_NAME="conqping"
INSTALL_DIR="$HOME/.local/bin"

# --- Function: Get Java Version ---
get_java_version() {
    if ! command -v java >/dev/null 2>&1; then
        echo "0"
        return
    fi
    # Extracts version from stderr (e.g., 'java version "1.8.0_..."' or 'openjdk 17.0.1 ...')
    # Use awk to handle various OpenJDK/Oracle outputs
    version=$(java -version 2>&1 | head -n 1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{print $1}')
    
    # If awk failed (newer formats without "version" keyword sometimes), try simplified parsing
    if [ -z "$version" ]; then
         version=$(java -version 2>&1 | head -n 1 | awk '{print $2}' | awk -F '.' '{print $1}' | tr -d '"')
    fi
    
    # Handle 1.8 -> 8
    if [ "$version" = "1" ]; then
        version=$(java -version 2>&1 | head -n 1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{print $2}')
    fi
    
    # Ensure it's a number
    if [[ "$version" =~ ^[0-9]+$ ]]; then
        echo "$version"
    else
        echo "0"
    fi
}

# --- Detect OS ---
OS="$(uname -s)"
case "$OS" in
    Linux*)     OS_TYPE="linux";;
    Darwin*)    OS_TYPE="macos";;
    *)          echo "Unsupported OS: $OS"; exit 1;;
esac

# --- Detect Java Status ---
JAVA_VER=$(get_java_version)
CAN_USE_JAVA=false
JAVA_STATUS=""

if [ "$JAVA_VER" -ge 8 ]; then
    JAVA_STATUS="Available (Java $JAVA_VER detected)"
    CAN_USE_JAVA=true
elif [ "$JAVA_VER" -gt 0 ]; then
    JAVA_STATUS="Disabled (Java $JAVA_VER is too old, requires 8+)"
else
    JAVA_STATUS="Disabled (No Java installation found)"
fi

# --- Menu Selection ---
echo "========================================"
echo "      ConqPing Installer Selection      "
echo "========================================"
echo ""
echo "[1] Install Native Binary (Recommended)"
echo "    - No dependencies required."
echo "    - Best performance."
echo ""
if [ "$CAN_USE_JAVA" = true ]; then
    echo "[2] Install Java JAR"
else
    echo "[2] Install Java JAR ($JAVA_STATUS)"
fi
echo "    - Requires Java 8+ installed."
echo "    - Cross-platform JAR."
echo ""
read -p "Select option [1/2] (Default: 1): " SELECTION

if [ -z "$SELECTION" ]; then SELECTION="1"; fi

if [ "$SELECTION" = "2" ]; then
    if [ "$CAN_USE_JAVA" = false ]; then
        echo "Error: Cannot select Option 2: $JAVA_STATUS"
        exit 1
    fi
    INSTALL_TYPE="JAR"
else
    INSTALL_TYPE="Native"
fi

# --- Installation Logic ---

if [ "$INSTALL_TYPE" = "Native" ]; then
    # Detect Architecture
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64) ARCH_TYPE="x64";;
        aarch64|arm64) ARCH_TYPE="arm64";;
        *) echo "Unsupported Architecture: $ARCH"; exit 1;;
    esac
    
    BINARY_NAME="conqping-${OS_TYPE}-${ARCH_TYPE}"
    TARGET_FILE="$APP_NAME"
else
    BINARY_NAME="ConqPing.jar"
    TARGET_FILE="ConqPing.jar"
fi

URL="https://github.com/$REPO/releases/latest/download/$BINARY_NAME"

echo ""
echo "Installing $APP_NAME ($INSTALL_TYPE)..."

# Create Install Directory
mkdir -p "$INSTALL_DIR"

# Download
echo "Downloading from $URL..."
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$INSTALL_DIR/$TARGET_FILE"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$URL" -O "$INSTALL_DIR/$TARGET_FILE"
else
    echo "Error: curl or wget is required to install."
    exit 1
fi

# If JAR, create wrapper script
if [ "$INSTALL_TYPE" = "JAR" ]; then
    WRAPPER_PATH="$INSTALL_DIR/$APP_NAME"
    echo "#!/bin/sh" > "$WRAPPER_PATH"
    echo 'DIR=$(dirname "$(realpath "$0")")' >> "$WRAPPER_PATH"
    echo "java -jar \"\$DIR/$TARGET_FILE\" \"\$@\"" >> "$WRAPPER_PATH"
    chmod +x "$WRAPPER_PATH"
    echo "Created wrapper script: $WRAPPER_PATH"
else
    chmod +x "$INSTALL_DIR/$TARGET_FILE"
fi

echo "Installed to $INSTALL_DIR/$TARGET_FILE"

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

echo ""
echo "Installation Complete! You can now run '$APP_NAME <IP>'"
