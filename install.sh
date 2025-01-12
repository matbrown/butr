#!/bin/bash

# Script Version
INSTALLER_VERSION="1.0.6"
REQUIRED_BUTR_VERSION="2.0.1"
MIN_BUTR_VERSION="2.0.0"
MAX_BUTR_VERSION="2.99.99"

# Define variables
TOOL_URL="https://raw.githubusercontent.com/matbrown/butr/refs/heads/main/butr.pl"
INSTALL_PATH="/usr/bin/butr"
ALIAS_PATH="/etc/profile.d/butr-aliases.sh"
TEST_DIR="/tmp/butr_test_$(date +%s)"
TEST_FILE="$TEST_DIR/test.txt"
FORCE_INSTALL=0
SKIP_TESTS=0

# Function to check if a command exists
check_command_exists() {
    local cmd="$1"
    
    # Check if it's a built-in command or function
    type "$cmd" >/dev/null 2>&1 && {
        echo "'$cmd' exists as $(type -t "$cmd")"
        return 0
    }
    
    # Check in common binary locations
    for path in $(echo "$PATH" | tr ':' '\n'); do
        if [ -f "$path/$cmd" ]; then
            echo "'$cmd' exists as command in $path/$cmd"
            return 0
        fi
    done
    
    return 1
}

# Function to verify alias safety
verify_alias_safety() {
    local cmd="$1"
    local fallback="$2"
    
    if result=$(check_command_exists "$cmd"); then
        echo "Warning: $result"
        echo "Cannot safely create alias '$cmd'"
        echo "Suggestion: Use '$fallback' instead"
        return 1
    fi
    return 0
}

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

# Function to setup aliases with safety checks
setup_aliases() {
    local alias_file="$ALIAS_PATH"
    local created_aliases=()
    local skipped_aliases=()
    local safe_b=true
    local safe_r=true
    
    echo "Checking command availability..."
    
    # Check 'b' command
    if ! verify_alias_safety "b" "butr -b"; then
        safe_b=false
    fi
    
    # Check 'r' command
    if ! verify_alias_safety "r" "butr -r"; then
        safe_r=false
    fi
    
    # If neither alias is safe, don't create the alias file
    if [ "$safe_b" = false ] && [ "$safe_r" = false ]; then
        echo "No aliases will be created due to existing commands"
        echo "Please use the full commands:"
        echo "  butr -b  (for backup)"
        echo "  butr -r  (for recovery)"
        return
    fi
    
    # Create alias file
    echo "# Global aliases for butr backup tool" > "$alias_file"
    
    # Add safe aliases
    if [ "$safe_b" = true ]; then
        echo "alias b='butr -b'" >> "$alias_file"
        created_aliases+=("b='butr -b'")
    else
        skipped_aliases+=("b")
    fi
    
    if [ "$safe_r" = true ]; then
        echo "alias r='butr -r'" >> "$alias_file"
        created_aliases+=("r='butr -r'")
    else
        skipped_aliases+=("r")
    fi
    
    # Set permissions
    chmod 644 "$alias_file"
    
    # Report results
    if [ ${#created_aliases[@]} -gt 0 ]; then
        echo "Created aliases:"
        printf "  %s\n" "${created_aliases[@]}"
    fi
    
    if [ ${#skipped_aliases[@]} -gt 0 ]; then
        echo "Skipped aliases (command exists):"
        printf "  %s\n" "${skipped_aliases[@]}"
        echo "Please use 'butr -b' and 'butr -r' directly for these operations"
    fi
}

# Function to clean up test files
cleanup_tests() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    echo "Test cleanup completed"
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

# Function to run tests
run_tests() {
    echo "Running installation tests..."
    
    # Create test directory and file
    mkdir -p "$TEST_DIR"
    echo "Test content" > "$TEST_FILE"
    
    echo "1. Testing butr command availability..."
    if ! command -v butr &> /dev/null; then
        echo "Error: butr command not found"
        cleanup_tests
        exit 1
    fi
    echo "✓ butr command is available"
    
    # Get installed butr version
    local installed_version=$(butr -v | grep -oP '(?<=version )[0-9.]+')
    echo "2. Testing version compatibility..."
    if ! check_version_compatibility "$installed_version"; then
        cleanup_tests
        exit 1
    fi
    echo "✓ Version compatibility check passed"
    
    echo "3. Testing execute permissions..."
    if [ ! -x "$INSTALL_PATH" ]; then
        echo "Error: butr is not executable"
        cleanup_tests
        exit 1
    fi
    echo "✓ Execute permissions are correct"
    
    echo "4. Testing backup functionality..."
    if ! butr -b "$TEST_FILE" &> /dev/null; then
        echo "Error: backup operation failed"
        cleanup_tests
        exit 1
    fi
    if [ ! -d "$HOME/.butr" ]; then
        echo "Error: backup directory was not created"
        cleanup_tests
        exit 1
    fi
    echo "✓ Backup operation successful"
    
    echo "5. Testing backup file creation..."
    BACKUP_PATH="$HOME/.butr$TEST_DIR"
    if [ ! "$(find "$BACKUP_PATH" -name "test.txt.butr.*" | wc -l)" -eq 1 ]; then
        echo "Error: backup file not found"
        cleanup_tests
        exit 1
    fi
    echo "✓ Backup file created correctly"
    
    # Clean up test files
    cleanup_tests
    
    echo "All tests passed successfully! ✓"
}

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

# Setup aliases
echo "Setting up command aliases..."
setup_aliases

# Run installation tests unless skipped
if [ "$SKIP_TESTS" -ne 1 ]; then
    run_tests
fi

# Print version information
print_version

# Remind about system-wide activation
echo ""
echo "Note: Users will need to log out and back in for aliases to take effect"
echo "      or source $ALIAS_PATH manually"
