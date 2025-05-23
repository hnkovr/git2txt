#!/bin/bash

# pbpaste Ubuntu Analog Installer
# Creates Ubuntu equivalents for macOS pbpaste/pbcopy commands

set -e

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_DIR="$HOME/_stash-2025-05-23/github/@hnkovr/git2txt/git2txt"

echo "Installing pbpaste/pbcopy analogs for Ubuntu..."

# Create installation directory if it doesn't exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$SCRIPT_DIR"

# Function to create pbcopy analog
create_pbcopy() {
    cat > "$INSTALL_DIR/pbcopy" << 'EOF'
#!/bin/bash
# pbcopy analog for Ubuntu using xclip
if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input
else
    echo "Error: Neither xclip nor xsel is installed." >&2
    echo "Install with: sudo apt install xclip" >&2
    exit 1
fi
EOF
    chmod +x "$INSTALL_DIR/pbcopy"
}

# Function to create pbpaste analog
create_pbpaste() {
    cat > "$INSTALL_DIR/pbpaste" << 'EOF'
#!/bin/bash
# pbpaste analog for Ubuntu using xclip
if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --output
else
    echo "Error: Neither xclip nor xsel is installed." >&2
    echo "Install with: sudo apt install xclip" >&2
    exit 1
fi
EOF
    chmod +x "$INSTALL_DIR/pbpaste"
}

# Check if xclip or xsel is installed
if ! command -v xclip >/dev/null 2>&1 && ! command -v xsel >/dev/null 2>&1; then
    echo "Installing xclip (clipboard utility)..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y xclip
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y xclip
    else
        echo "Error: Could not install xclip. Please install it manually:"
        echo "  sudo apt install xclip"
        exit 1
    fi
fi

# Create the analog scripts
create_pbcopy
create_pbpaste

# Create symlinks in the specified directory
ln -sf "$INSTALL_DIR/pbpaste" "$SCRIPT_DIR/pbpaste"
ln -sf "$INSTALL_DIR/pbcopy" "$SCRIPT_DIR/pbcopy"

# Add to PATH if not already there
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "Adding $INSTALL_DIR to PATH..."
    
    # Add to .bashrc
    if [[ -f "$HOME/.bashrc" ]]; then
        echo "" >> "$HOME/.bashrc"
        echo "# Add local bin to PATH for pbpaste/pbcopy" >> "$HOME/.bashrc"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.bashrc"
    fi
    
    # Add to .zshrc if it exists
    if [[ -f "$HOME/.zshrc" ]]; then
        echo "" >> "$HOME/.zshrc"
        echo "# Add local bin to PATH for pbpaste/pbcopy" >> "$HOME/.zshrc"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.zshrc"
    fi
    
    # Export for current session
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "✅ Installation complete!"
echo ""
echo "Created files:"
echo "  - $INSTALL_DIR/pbpaste"
echo "  - $INSTALL_DIR/pbcopy"
echo "  - $SCRIPT_DIR/pbpaste (symlink)"
echo "  - $SCRIPT_DIR/pbcopy (symlink)"
echo ""
echo "Usage:"
echo "  echo 'Hello World' | pbcopy    # Copy to clipboard"
echo "  pbpaste                        # Paste from clipboard"
echo ""
echo "Note: Restart your terminal or run 'source ~/.bashrc' to use the commands."

# Test the installation
echo "Testing installation..."
if command -v pbpaste >/dev/null 2>&1; then
    echo "✅ pbpaste command is available"
else
    echo "⚠️  pbpaste not in PATH yet. Restart terminal or run: source ~/.bashrc"
fi

if command -v pbcopy >/dev/null 2>&1; then
    echo "✅ pbcopy command is available"
else
    echo "⚠️  pbcopy not in PATH yet. Restart terminal or run: source ~/.bashrc"
fi
