#!/bin/sh

# script that creates git and gitk aliases which operate on the etckeeper git repo when logged in as root

# note that this script targets POSIX shell (/bin/sh) compliance, in order to maximize portability

# Ensure the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Step 1: Create the POSIX-compliant git functions script in /etc/profile.d/
cat << 'EOF' > /etc/profile.d/etckeeper-git-functions.sh
# /etc/profile.d/etckeeper-git-functions.sh

# Define git and gitk functions for root user only
if [ "$(id -u)" -eq 0 ]; then
    git() { command git -C /etc "$@"; }
    gitk() { command gitk -C /etc "$@"; }
    gg() { command git -C /etc gui "$@"; }
    echo "/etc/profile.d/etckeeper-git-functions.sh defined functions: git, gitk, gg"
fi
EOF

# Make the script executable
chmod +x /etc/profile.d/etckeeper-git-functions.sh

# Step 2: Check if SELinux is enabled and restore context (RHEL-based systems)
if command -v getenforce >/dev/null && [ "$(getenforce)" != "Disabled" ]; then
    restorecon -v /etc/profile.d/etckeeper-git-functions.sh
fi

# Step 3: Append the function script to /root/.bashrc if not already present
if ! grep -q 'etckeeper-git-functions.sh' /root/.bashrc 2>/dev/null; then
    echo "Appending /etc/profile.d/etckeeper-git-functions.sh to /root/.bashrc"
    echo ". /etc/profile.d/etckeeper-git-functions.sh" >> /root/.bashrc
else
    echo "etckeeper-git-functions.sh is already sourced in /root/.bashrc"
fi

echo "Setup complete! Test your changes by starting a new root shell."
