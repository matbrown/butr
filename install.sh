#!/bin/bash

# Exit on any error
set -e

# Define variables
TOOL_URL="https://mbr.tools.co.uk/butr"
INSTALL_PATH="/usr/bin/butr"
ALIAS_PATH="/etc/profile.d/butr-aliases.sh"
TEST_DIR="/tmp/butr_test_$(date +%s)"
TEST_FILE="$TEST_DIR/test.txt"

# Function to clean up test files
cleanup_tests() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    echo "Test cleanup completed"
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
    
    echo "2. Testing execute permissions..."
    if [ ! -x "$INSTALL_PATH" ]; then
        echo "Error: butr is not executable"
        cleanup_tests
        exit 1
    fi
    echo "✓ Execute permissions are correct"
    
    echo "3. Testing backup functionality..."
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
    
    echo "4. Testing backup file creation..."
    BACKUP_PATH="$HOME/.butr$TEST_DIR"
    if [ ! "$(find "$BACKUP_PATH" -name "test.txt.butr.*" | wc -l)" -eq 1 ]; then
        echo "Error: backup file not found"
        cleanup_tests
        exit 1
    fi
    echo "✓ Backup file created correctly"
    
    echo "5. Testing file modification and backup..."
    echo "Modified content" > "$TEST_FILE"
    if ! butr -b "$TEST_FILE" &> /dev/null; then
        echo "Error: second backup operation failed"
        cleanup_tests
        exit 1
    fi
    if [ ! "$(find "$BACKUP_PATH" -name "test.txt.butr.*" | wc -l)" -eq 2 ]; then
        echo "Error: second backup file not found"
        cleanup_tests
        exit 1
    fi
    echo "✓ Multiple backup versions working correctly"
    
    echo "6. Testing recovery functionality..."
    if ! butr -r "$TEST_FILE" <<< "1" &> /dev/null; then
        echo "Error: recovery operation failed"
        cleanup_tests
        exit 1
    fi
    if [ ! "$(cat "$TEST_FILE")" = "Modified content" ]; then
        echo "Error: file content not recovered correctly"
        cleanup_tests
        exit 1
    fi
    echo "✓ Recovery operation successful"
    
    echo "7. Testing alias file creation..."
    if [ ! -f "$ALIAS_PATH" ]; then
        echo "Error: alias file not created"
        cleanup_tests
        exit 1
    fi
    echo "✓ Alias file created correctly"
    
    echo "8. Testing alias file permissions..."
    if [ ! "$(stat -c %a "$ALIAS_PATH")" = "644" ]; then
        echo "Error: alias file has incorrect permissions"
        cleanup_tests
        exit 1
    fi
    echo "✓ Alias file permissions are correct"

    echo "9. Testing alias functionality..."
    source "$ALIAS_PATH"
    if ! type b &> /dev/null || ! type r &> /dev/null; then
        echo "Error: aliases not defined after sourcing"
        cleanup_tests
        exit 1
    fi
    echo "✓ Aliases defined correctly"
    
    # Clean up test files
    cleanup_tests
    
    echo "All tests passed successfully! ✓"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: Please run as root (use sudo)"
    exit 1
fi

echo "Installing butr backup tool..."

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

# Run installation tests
run_tests

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

# Remind about system-wide activation
echo ""
echo "Note: Users will need to log out and back in for aliases to take effect"
echo "      or source the aliases file manually: source $ALIAS_PATH"
