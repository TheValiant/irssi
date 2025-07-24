#!/bin/bash

# This script downloads a statically compiled irssi binary and installs it to ~/bin.
# It is idempotent and can be run multiple times without causing issues.
#
# The original source and build script can be found at:
# https://github.com/TheValiant/irssi

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
INSTALL_DIR="$HOME/bin"
BINARY_NAME="irssi"
BINARY_URL="https://github.com/TheValiant/irssi/releases/download/1.4.5-stable/irssi"
DEST_PATH="$INSTALL_DIR/$BINARY_NAME"

# --- Script ---

echo "--- Starting irssi binary installation ---"

# 1. Create the installation directory if it doesn't exist
echo "Ensuring installation directory exists: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# 2. Download the irssi binary
echo "Downloading irssi binary from $BINARY_URL..."
curl --fail --location --output "$DEST_PATH" "$BINARY_URL"

# 3. Make the binary executable
echo "Setting execute permissions on $DEST_PATH..."
chmod +x "$DEST_PATH"

echo "✅ Irssi binary is now available at: $DEST_PATH"
file "$DEST_PATH"

# 4. Ensure the installation directory is in the user's PATH
# This function checks a given shell configuration file and adds the installation
# directory to the PATH if it's not already there.
update_shell_config() {
    local config_file="$1"
    local path_to_add="$2"
    # The string to be added to the config file
    local export_line="export PATH=\"$path_to_add:\$PATH\""

    # Check if the config file exists
    if [ ! -f "$config_file" ]; then
        echo "ⓘ Shell config file not found: $config_file. Skipping."
        return
    fi

    # Check if the directory is already in a PATH export line in the file.
    # This makes the script idempotent.
    if grep -q "export PATH=.*$path_to_add" "$config_file"; then
        echo "✅ '$path_to_add' is already in the PATH in $config_file."
    else
        echo "-> Adding '$path_to_add' to PATH in $config_file..."
        # Append the export line to the config file, with comments.
        echo -e "\n# Add local user binaries to PATH (for irssi)" >> "$config_file"
        echo "$export_line" >> "$config_file"
        echo "✅ Successfully added. Please restart your shell or run 'source $config_file'."
    fi
}

echo ""
echo "--- Checking shell configurations for PATH update ---"

# List of common shell configuration files to check
# We check both .bash_profile (for login shells) and .bashrc (for interactive shells)
# Zsh uses .zshrc
SHELL_CONFIG_FILES=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile")

for config in "${SHELL_CONFIG_FILES[@]}"; do
    update_shell_config "$config" "$INSTALL_DIR"
done

echo ""
echo "--- Installation Complete! ---"
echo "You can now use irssi by typing 'irssi' in a new terminal."
echo "If the 'irssi' command is not found, you may need to restart your terminal session"
echo "or manually source your shell's configuration file (e.g., 'source ~/.zshrc')."
