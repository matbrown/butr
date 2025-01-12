#!/bin/bash

# Script Version
INSTALLER_VERSION="1.0.2"
REQUIRED_BUTR_VERSION="2.0.1"
MIN_BUTR_VERSION="2.0.1"
MAX_BUTR_VERSION="2.99.99"

# Print version information
print_version() {
    echo "butr installer version $INSTALLER_VERSION"
    echo "Compatible with butr versions $MIN_BUTR_VERSION to $MAX_BUTR_VERSION"
}

# Function to check if butr is installed and get its version
check_existing_installation() {
    if command -v butr &> /dev/null; then
        local current_version=$(butr -v | grep -oP '(?<=version )[0-9.]+')
        echo "$current_version"
        return 0
    fi
    return 1
}

# Function to prompt for confirmation
confirm_action() {
    local prompt="$1"
    local default="$2"
    
    if [[ "$default" == "Y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    read -r -p "$prompt" response
    response=${response,,} # Convert to lowercase
    
    if [[ "$default" == "Y" ]]; then
        [[ "$response" =~ ^(no|n)$ ]] && return 1
        return 0
    else
        [[ "$response" =~ ^(yes|y)$ ]] && return 0
        return 1
    fi
}

# Function to compare version numbers
version_compare() {
    if [[ $1 == $2 ]]; then
        echo "equal"
        return
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # Fill empty positions in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    # Fill empty positions in ver2 with zeros
    for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
        ver2[i]=0
    done
    # Compare version numbers
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            echo "greater"
            return
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            echo "less"
            return
        fi
    done
    echo "equal"
}

# Check version compatibility
check_version_compatibility() {
    local butr_version=$1
    
    # Check minimum version
    if [[ $(version_compare "$butr_version" "$MIN_BUTR_VERSION") == "less" ]]; then
        echo "Error: butr version $butr_version is lower than minimum required version $MIN_BUTR_VERSION"
        return 1
    fi
    
    # Check maximum version
    if [[ $(version_compare "$butr_version" "$MAX_BUTR_VERSION") == "greater" ]]; then
        echo "Error: butr version $butr_version is higher than maximum supported version $MAX_BUTR_VERSION"
        return 1
    fi
    
    return 0
}

# Exit on any error
set -e

# Define variables
TOOL_URL="https://raw.githubusercontent.com/matbrown/butr/refs/heads/main/butr.pl"
INSTALL_PATH="/usr/bin/butr"
ALIAS_PATH="/etc/profile.d/butr-aliases.sh"
TEST_DIR="/tmp/butr_test_$(date +%s)"
TEST_FILE="$TEST_DIR/test.txt"
FORCE_INSTALL=0

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            print_version
            exit 0
            ;;
        --skip-tests)
            SKIP_TESTS=1
            shift
            ;;
        -f|--force)
            FORCE_INSTALL=1
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -v, --version    Show version information"
            echo "  --skip-tests     Skip installation tests"
            echo "  -f, --force      Force installation (overwrite existing)"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: Please run as root (use sudo)"
    exit 1
fi

# Check for existing installation
if existing_version=$(check_existing_installation); then
    echo "butr version $existing_version is already installed"
    
    # Compare versions
    version_status=$(version_compare "$REQUIRED_BUTR_VERSION" "$existing_version")
    
    if [ "$version_status" == "equal" ]; then
        echo "This is the same version as the installer provides"
        if [ "$FORCE_INSTALL" -ne 1 ]; then
            if ! confirm_action "Do you want to reinstall?" "N"; then
                echo "Installation cancelled"
                exit 0
            fi
        fi
    elif [ "$version_status" == "greater" ]; then
        echo "This is an upgrade from version $existing_version to $REQUIRED_BUTR_VERSION"
        if [ "$FORCE_INSTALL" -ne 1 ]; then
            if ! confirm_action "Do you want to upgrade?" "Y"; then
                echo "Installation cancelled"
                exit 0
            fi
        fi
    else
        echo "Warning: This would downgrade from version $existing_version to $REQUIRED_BUTR_VERSION"
        if [ "$FORCE_INSTALL" -ne 1 ]; then
            if ! confirm_action "Do you want to downgrade?" "N"; then
                echo "Installation cancelled"
                exit 0
            fi
        fi
    fi
fi

echo "Installing butr backup tool version $REQUIRED_BUTR_VERSION..."

# Download the tool using curl
if ! curl -sSfL "$TOOL_URL" -o "$INSTALL_PATH"; then
    echo "Error: Failed to download butr tool"
    exit 1
fi

# Set permissions (rwxr-xr-x)
if ! chmod 755 "$INSTALL_PATH"; then
    echo "Error: Failed to set permissions"
    exit 1
fi

# Create global aliases file
cat > "$ALIAS_PATH" << 'EOF'
# Global aliases for butr backup tool
alias b='butr -b'
alias r='butr -r'
EOF

# Set permissions for aliases file (rw-r--r--)
chmod 644 "$ALIAS_PATH"

# Run installation tests unless skipped
if [ -z "$SKIP_TESTS" ]; then
    run_tests
fi

# Verify installation
if [ -x "$INSTALL_PATH" ] && [ -f "$ALIAS_PATH" ]; then
    echo "Successfully installed butr to $INSTALL_PATH"
    echo "Created global aliases in $ALIAS_PATH"
    echo "The following aliases are now available (after login):"
    echo "  b  -> butr -b (backup)"
    echo "  r  -> butr -r (recover)"
    echo ""
    echo "To use aliases in current session, run:"
    echo "  source $ALIAS_PATH"
else
    echo "Error: Installation verification failed"
    exit 1
fi

# Print version information
print_version

# Remind about system-wide activation
echo ""
echo "Note: Users will need to log out and back in for aliases to take effect"
echo "      or source the aliases file manually: source $ALIAS_PATH"
