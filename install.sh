#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: Please run as root (use sudo)"
    exit 1
fi

# Define variables
TOOL_URL="https://mbr.tools.co.uk/butr"
INSTALL_PATH="/usr/bin/butr"
ALIAS_PATH="/etc/profile.d/butr-aliases.sh"

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
