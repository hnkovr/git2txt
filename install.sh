#!/bin/bash
clear
pwd
# ./install.sh
cat $0
cat install.py

set -ex

# Create virtual environment
uv venv

# Activate the virtual environment and run the installation
source .venv/bin/activate

SCRIPT_DIR=$(dirname "$(readlink -f "$0" || realpath "$0")")
python "$SCRIPT_DIR/install.py"

# Check if git2text binary exists in venv
if [ -f ".venv/bin/git2text" ]; then
    echo ""
    echo "🎉 Installation successful!"
    echo ""
    echo "To use git2text, you have several options:"
    echo ""
    echo "1. Activate the virtual environment each time:"
    echo "   source .venv/bin/activate"
    echo "   git2text --help"
    echo ""
    echo "2. Use the full path directly:"
    echo "   $(pwd)/.venv/bin/git2text --help"
    echo ""
    echo "3. Create a global alias (add to your ~/.bashrc or ~/.zshrc):"
    echo "   alias git2text='$(pwd)/.venv/bin/git2text'"
    echo ""
    echo "4. Create a symlink (requires sudo):"
    read -p "   Do you want to create a symlink in /usr/local/bin? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo ln -sf "$(pwd)/.venv/bin/git2text" /usr/local/bin/git2text
        echo "   ✅ Symlink created! You can now use 'git2text' globally."
    else
        echo "   Symlink not created."
    fi
    echo ""
    echo "Testing the installation:"
    .venv/bin/git2text --help || echo "❌ Something went wrong with the installation"
else
    echo "❌ git2text binary not found in .venv/bin/"
    echo "Installation may have failed."
fi
