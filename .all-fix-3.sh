#!/bin/bash

# all-gen.sh - Generate all changes to fix git2txt installation with uv

set -e

echo "Generating fixes for git2txt installation with uv..."

# Fix the install.sh script to properly set up git2text for global usage
cat > install.sh << 'EOF'
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
EOF

# Enhanced install.py with better post-installation handling
cat > install.py << 'EOF'
import os
import sys
import subprocess
import ctypes
import platform
import sysconfig

def is_admin():
    """Check if the script is running with administrative privileges."""
    if platform.system() == 'Windows':
        try:
            return ctypes.windll.shell32.IsUserAnAdmin()
        except:
            return False
    else:
        return os.geteuid() == 0

def install_package():
    """Install the package and determine the scripts path."""
    print("Installing the package...")
    try:
        # Determine the directory where install.py is located
        script_dir = os.path.dirname(os.path.abspath(__file__))

        # Absolute path to the package directory
        package_dir = script_dir

        # Check if we're in a virtual environment and use appropriate pip command
        in_venv = hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix)
        
        if in_venv:
            # We're in a virtual environment, use uv pip directly
            try:
                subprocess.run(['uv', 'pip', 'install', '-e', package_dir], check=True)
                print("Package installed successfully using uv pip.")
            except (subprocess.CalledProcessError, FileNotFoundError):
                # Fallback to regular pip if uv fails
                try:
                    subprocess.run([sys.executable, '-m', 'pip', 'install', '-e', package_dir], check=True)
                    print("Package installed successfully using pip.")
                except subprocess.CalledProcessError as e:
                    print(f"An error occurred while installing the package: {e}")
                    sys.exit(1)
        else:
            # Not in virtual environment, prefer uv
            try:
                subprocess.run(['uv', '--version'], check=True, stdout=subprocess.DEVNULL)
                subprocess.run(['uv', 'pip', 'install', '-e', package_dir], check=True)
                print("Package installed successfully using uv pip.")
            except (subprocess.CalledProcessError, FileNotFoundError):
                print("uv is not available in the current environment.")
                print("Please install uv or use a Python interpreter that has pip installed.")
                print("You can install uv with: curl -LsSf https://astral.sh/uv/install.sh | sh")
                sys.exit(1)

    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)

    # Find the scripts path where the binary is installed
    binary_name = 'git2text.exe' if platform.system() == 'Windows' else 'git2text'
    scripts_path = None

    # For virtual environments, check the venv's scripts directory first
    if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
        if platform.system() == 'Windows':
            venv_scripts = os.path.join(sys.prefix, 'Scripts')
        else:
            venv_scripts = os.path.join(sys.prefix, 'bin')
        
        binary_path = os.path.join(venv_scripts, binary_name)
        if os.path.exists(binary_path):
            scripts_path = venv_scripts
            print(f"✅ Found git2text binary at: {binary_path}")

    # If not found in venv, check standard schemes
    if not scripts_path:
        schemes = []
        if platform.system() == 'Windows':
            schemes.extend(['nt', 'nt_user', 'nt_venv'])
        else:
            schemes.extend(['posix_prefix', 'posix_user', 'posix_home', 'posix_venv'])

        for scheme in schemes:
            try:
                paths = sysconfig.get_paths(scheme=scheme)
            except KeyError:
                continue
            possible_scripts_path = paths.get('scripts')
            if possible_scripts_path:
                binary_path = os.path.join(possible_scripts_path, binary_name)
                if os.path.exists(binary_path):
                    scripts_path = possible_scripts_path
                    print(f"✅ Found git2text binary at: {binary_path}")
                    break

    if not scripts_path:
        print("Warning: Could not find the binary in any standard scripts directories.")
        print("The package was installed but the binary location could not be determined.")
        # Let's check if we can run it as a module instead
        try:
            result = subprocess.run([sys.executable, '-m', 'git2text', '--help'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                print("✅ The package can be run as a Python module: python -m git2text")
            else:
                print("❌ Cannot run as module either")
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
            print("❌ Cannot run as module")
        return None

    scripts_path = os.path.abspath(scripts_path)
    return scripts_path

def main():
    # Detect if running in a virtual environment
    if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
        in_virtual_env = True
        print("✅ Running in virtual environment.")
    else:
        in_virtual_env = False
        print("⚠️  Warning: You are about to install git2text in the system Python environment.")
        choice = input("Do you want to continue with the installation? [y/N]: ").strip().lower()
        if choice != 'y':
            print("Installation aborted by user.")
            sys.exit(0)

    scripts_path = install_package()
    if scripts_path:
        print(f"✅ Python Scripts path: {scripts_path}")
    
    print("Installation completed!")

if __name__ == '__main__':
    main()
EOF

# Make the install.sh executable
chmod +x install.sh

# Create a helper script for easy activation
cat > activate-git2text.sh << 'EOF'
#!/bin/bash
# Helper script to activate git2text virtual environment
echo "Activating git2text virtual environment..."
source .venv/bin/activate
echo "Virtual environment activated. You can now use 'git2text' directly."
echo "Type 'deactivate' to exit the virtual environment."
EOF

chmod +x activate-git2text.sh

echo "✅ Generated enhanced installation scripts"
echo ""
echo "Files created:"
echo "1. install.sh - Main installation script"
echo "2. install.py - Enhanced Python installation logic"
echo "3. activate-git2text.sh - Helper script to activate the environment"
echo ""
echo "Key improvements:"
echo "1. Better binary detection and verification"
echo "2. Post-installation options (symlink, alias, direct path)"
echo "3. Interactive setup for global usage"
echo "4. Helper script for easy environment activation"
echo ""
echo "Now you can run: ./install.sh"
echo "After installation, you'll have multiple options to use git2text globally."
