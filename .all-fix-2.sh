#!/bin/bash

# all-gen.sh - Generate all changes to fix git2txt installation with uv

set -e

echo "Generating fixes for git2txt installation with uv..."

# Fix the install.sh script to properly use the virtual environment
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
EOF

# Fix the install.py script to work better with virtual environments
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
                    break

    if not scripts_path:
        print("Warning: Could not find the binary in any standard scripts directories.")
        print("The package was installed but the binary location could not be determined.")
        return None

    scripts_path = os.path.abspath(scripts_path)
    return scripts_path

def get_environment_variable(variable, scope='user'):
    """Retrieve the value of an environment variable."""
    if platform.system() == 'Windows':
        if scope == 'user':
            return os.environ.get(variable, '')
        elif scope == 'system':
            # Get system environment variable using registry
            import winreg
            try:
                with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,
                                    r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
                                    0, winreg.KEY_READ) as key:
                    value, _ = winreg.QueryValueEx(key, variable)
                return value
            except Exception as e:
                print(f"Error accessing system environment variable {variable}: {e}")
                return ''
    else:
        return os.environ.get(variable, '')

def set_environment_variable(variable, value, scope='user'):
    """Set the value of an environment variable."""
    if platform.system() == 'Windows':
        if scope == 'user':
            command = f'setx {variable} "{value}"'
        elif scope == 'system':
            command = f'setx {variable} "{value}" /M'
        else:
            print("Invalid scope specified.")
            return False
        try:
            subprocess.run(command, shell=True, check=True)
            print(f"Successfully updated {variable} in the {scope} environment variables.")
            print("You may need to restart your command prompt or computer for changes to take effect.")
            return True
        except subprocess.CalledProcessError as e:
            print(f"An error occurred while updating {variable}: {e}")
            return False
    else:
        # On Unix-based systems, inform the user to modify their shell profile
        print(f"Please add the following line to your shell profile (~/.bashrc, ~/.zshrc, etc.):")
        print(f'\nexport {variable}="{value}"\n')
        return True

def is_path_in_variable(scripts_path, variable_value):
    """Check if a given path is in the specified environment variable."""
    scripts_path_normalized = os.path.normcase(os.path.normpath(scripts_path.rstrip(os.sep)))
    paths = variable_value.split(os.pathsep)
    paths_normalized = [os.path.normcase(os.path.normpath(p.rstrip(os.sep))) for p in paths]
    return scripts_path_normalized in paths_normalized

def run_as_admin():
    """Re-run the script with administrative privileges."""
    if platform.system() == 'Windows':
        script = sys.argv[0]
        params = ' '.join([f'"{arg}"' for arg in sys.argv[1:]])
        ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, f'"{script}" {params}', None, 1)
    else:
        args = ['sudo', sys.executable] + sys.argv
        subprocess.check_call(args)

def try_add_path_to_environment_variable(scripts_path, variable, scope):
    """Attempt to add the scripts path to the specified environment variable."""
    if scope == 'user':
        max_path_length = 2047
        path_value = get_environment_variable(variable, scope='user')
    elif scope == 'system':
        max_path_length = 4095
        path_value = get_environment_variable(variable, scope='system')
    else:
        print("Invalid scope specified.")
        return False

    new_path_elements = path_value.split(os.pathsep) if path_value else []
    if scripts_path not in new_path_elements:
        new_path_elements.append(scripts_path)
    new_path = os.pathsep.join(new_path_elements)
    if len(new_path) > max_path_length:
        print(f"Cannot add scripts path to {scope} PATH because it exceeds the maximum length.")
        return False

    print(f"Scripts path is not in the {scope} PATH.")
    privilege_note = " Administrator privileges are required." if scope == 'system' else ""
    choice = input(f"Do you want to add it to the {scope} PATH?{privilege_note} [y/N]: ").strip().lower()
    if choice != 'y':
        print(f"No changes were made to the {scope} PATH.")
        return False

    if scope == 'system' and not is_admin():
        print("Administrator privileges are required to modify the system PATH.")
        run_as_admin()
        sys.exit()

    success = set_environment_variable(variable, new_path, scope)
    return success

def check_and_add_scripts_path_windows(scripts_path):
    """Check and add the scripts path to the PATH environment variable on Windows."""
    user_path = get_environment_variable('PATH', scope='user')
    system_path = get_environment_variable('PATH', scope='system')

    in_user_path = is_path_in_variable(scripts_path, user_path)
    in_system_path = is_path_in_variable(scripts_path, system_path)

    if in_user_path or in_system_path:
        location = 'user PATH' if in_user_path else 'system PATH'
        print(f"Scripts path is already in the {location}. No changes needed.")
        return

    if try_add_path_to_environment_variable(scripts_path, 'PATH', scope='user'):
        print("Scripts path successfully added to the user PATH.")
    elif try_add_path_to_environment_variable(scripts_path, 'PATH', scope='system'):
        print("Scripts path successfully added to the system PATH.")
    else:
        print("The script path was not added to PATH variable. Please consider adding the script path to PATH manually.")
        print(f"Script path: {scripts_path}")

def check_and_create_symlink_unix(scripts_path):
    """Check and create a symlink to git2text in /usr/local/bin on Unix-based systems."""
    git2text_script = os.path.join(scripts_path, 'git2text')
    target_path = '/usr/local/bin/git2text'

    if os.path.exists(target_path):
        print(f"{target_path} already exists.")
        return

    print(f"{target_path} does not exist.")
    choice = input("Do you want to create a symlink to git2text in /usr/local/bin? [y/N]: ").strip().lower()
    if choice != 'y':
        print("No changes were made.")
        return

    if not is_admin():
        print("Root privileges are required to create a symlink in /usr/local/bin.")
        run_as_admin()
        sys.exit()

    try:
        if os.path.islink(target_path) or os.path.exists(target_path):
            overwrite = input(f"A file already exists at {target_path}. Do you want to overwrite it? [y/N]: ").strip().lower()
            if overwrite != 'y':
                print("No changes were made.")
                return
            else:
                os.remove(target_path)
        os.symlink(git2text_script, target_path)
        print(f"Successfully created symlink to git2text at {target_path}")
    except Exception as e:
        print(f"An error occurred while creating symlink: {e}")

def main():
    # Detect if running in a virtual environment
    if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
        in_virtual_env = True
        print("Running in virtual environment.")
    else:
        in_virtual_env = False
        print("Warning: You are about to install git2text in the system Python environment.")
        choice = input("Do you want to continue with the installation? [y/N]: ").strip().lower()
        if choice != 'y':
            print("Installation aborted by user.")
            sys.exit(0)

    scripts_path = install_package()
    if scripts_path is None:
        if in_virtual_env:
            print("\nThe package was installed in the virtual environment.")
            print("To use git2text, make sure the virtual environment is activated:")
            print("  source .venv/bin/activate")
            print("Then you can use: python -m git2text")
        sys.exit(1)
    print(f"Python Scripts path: {scripts_path}")

    if platform.system() == 'Windows':
        check_and_add_scripts_path_windows(scripts_path)
    else:
        if in_virtual_env:
            print("\nThe package was installed successfully in the virtual environment.")
            print("To use git2text globally, you can:")
            print("1. Activate the virtual environment: source .venv/bin/activate")
            print("2. Then use: git2text")
            print("3. Or use directly: python -m git2text")
        else:
            check_and_create_symlink_unix(scripts_path)

if __name__ == '__main__':
    main()
EOF

# Make the install.sh executable
chmod +x install.sh

echo "✅ Generated fixed install.sh and install.py files"
echo ""
echo "Key changes made:"
echo "1. Added 'source .venv/bin/activate' to properly activate the virtual environment"
echo "2. Changed 'python3' to 'python' to use the activated virtual environment's Python"
echo "3. Enhanced binary detection to check virtual environment paths first"
echo "4. Added fallback pip installation method for better compatibility"
echo "5. Improved messaging for virtual environment usage"
echo ""
echo "Now you can run: ./install.sh"
echo "The script will:"
echo "- Create a virtual environment"
echo "- Activate it"
echo "- Install git2text within the virtual environment"
echo "- Provide instructions for usage"
