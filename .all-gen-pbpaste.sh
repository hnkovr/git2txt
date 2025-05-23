#!/bin/bash

# .all-gen-pbpaste.sh - Universal clipboard paste for Linux
# Works across X11, Wayland, different distros, and edge cases
# Usage: ./all-gen-pbpaste.sh [selection]
# selection can be: clipboard (default), primary, secondary

SELECTION="${1:-clipboard}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect display server
detect_display_server() {
    if [ -n "$WAYLAND_DISPLAY" ]; then
        echo "wayland"
    elif [ -n "$DISPLAY" ]; then
        echo "x11"
    else
        echo "unknown"
    fi
}

# Function to try clipboard paste with various methods
try_paste() {
    local method="$1"
    local selection="$2"
    
    case "$method" in
        "wl-paste")
            if [ "$selection" = "primary" ]; then
                wl-paste --primary 2>/dev/null
            else
                wl-paste 2>/dev/null
            fi
            ;;
        "xclip")
            xclip -o -selection "$selection" 2>/dev/null
            ;;
        "xsel")
            case "$selection" in
                "clipboard") xsel --clipboard --output 2>/dev/null ;;
                "primary") xsel --primary --output 2>/dev/null ;;
                "secondary") xsel --secondary --output 2>/dev/null ;;
            esac
            ;;
        "termux-clipboard-get")
            termux-clipboard-get 2>/dev/null
            ;;
        "powershell")
            # WSL case
            powershell.exe -command "Get-Clipboard" 2>/dev/null | tr -d '\r'
            ;;
        "clip.exe")
            # Alternative WSL method - this is actually for setting clipboard
            # but we'll skip this for paste
            return 1
            ;;
        "pbpaste")
            # macOS (in case script runs on macOS)
            pbpaste 2>/dev/null
            ;;
        "dcop")
            # KDE 3.x fallback
            dcop klipper klipper getClipboardContents 2>/dev/null
            ;;
        "qdbus")
            # KDE 4+ fallback
            qdbus org.kde.klipper /klipper getClipboardContents 2>/dev/null
            ;;
    esac
}

# Main logic
main() {
    local display_server
    display_server=$(detect_display_server)
    
    # Define methods to try in order of preference
    local methods=()
    
    case "$display_server" in
        "wayland")
            methods=("wl-paste" "xclip" "xsel" "termux-clipboard-get" "powershell" "pbpaste" "qdbus" "dcop")
            ;;
        "x11")
            methods=("xclip" "xsel" "wl-paste" "termux-clipboard-get" "powershell" "pbpaste" "qdbus" "dcop")
            ;;
        *)
            # Unknown environment - try everything
            methods=("wl-paste" "xclip" "xsel" "termux-clipboard-get" "powershell" "pbpaste" "qdbus" "dcop")
            ;;
    esac
    
    # Try each method until one works
    for method in "${methods[@]}"; do
        if command_exists "$method" || command_exists "${method%.*}"; then
            local result
            result=$(try_paste "$method" "$SELECTION")
            local exit_code=$?
            
            if [ $exit_code -eq 0 ] && [ -n "$result" ]; then
                echo "$result"
                return 0
            fi
        fi
    done
    
    # If nothing worked, provide helpful error message
    echo "Error: No working clipboard tool found." >&2
    echo "Please install one of the following:" >&2
    echo "  - For Wayland: wl-clipboard (wl-paste)" >&2
    echo "  - For X11: xclip or xsel" >&2
    echo "  - sudo apt install wl-clipboard xclip xsel  # Debian/Ubuntu" >&2
    echo "  - sudo dnf install wl-clipboard xclip xsel  # Fedora" >&2
    echo "  - sudo pacman -S wl-clipboard xclip xsel    # Arch" >&2
    return 1
}

# Handle special arguments
case "$1" in
    "-h"|"--help")
        echo "Usage: $0 [selection]"
        echo "  selection: clipboard (default), primary, secondary"
        echo ""
        echo "Universal clipboard paste for Linux (X11/Wayland)"
        echo "Automatically detects and uses available clipboard tools."
        exit 0
        ;;
    "-v"|"--version")
        echo "all-gen-pbpaste.sh v1.0"
        exit 0
        ;;
    "--install")
        echo "Detected system: $(detect_display_server)"
        echo "Installing clipboard tools..."
        
        # Auto-detect package manager and install
        if command_exists apt; then
            sudo apt update && sudo apt install -y wl-clipboard xclip xsel
        elif command_exists dnf; then
            sudo dnf install -y wl-clipboard xclip xsel
        elif command_exists pacman; then
            sudo pacman -S wl-clipboard xclip xsel
        elif command_exists zypper; then
            sudo zypper install wl-clipboard xclip xsel
        elif command_exists pkg; then
            # Termux
            pkg install termux-api
        else
            echo "Unknown package manager. Please install manually."
            exit 1
        fi
        exit 0
        ;;
esac

# Run main function
main

