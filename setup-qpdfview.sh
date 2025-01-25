#!/bin/bash

# script that modifies GLOBAL qpdfview desktop startup configuration to omit the
# --unique cmdline parameter which causes new PDF opens to open in a new tab of
# any existing qpdfview window/session (I find this behavior very annoying and
# unproductive.

# Ensure the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Step 1: Define variables
DESKTOP_DIR="/usr/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/qpdfview.desktop"
APT_HOOK="/etc/apt/apt.conf.d/99-qpdfview-remove-unique"
SED_COMMAND=("sed" "-i" "s/--unique/--non-unique/g" "$DESKTOP_FILE")

showDesktopEntrySection() {
  awk '/^\[Desktop Entry\]/ {p=1; next} p && /^\[/ {exit} p' "$DESKTOP_FILE";
  }

refreshDesktopDatabase() {
  echo "Refreshing the desktop database..."
  update-desktop-database "$DESKTOP_DIR"
  }

echo "before:"
showDesktopEntrySection

# Step 2: Apply the initial sed command
echo "Applying sed command to remove --unique..."
"${SED_COMMAND[@]}"

echo
echo "after:"
showDesktopEntrySection

refreshDesktopDatabase

exit 0

# Step 3: Verify the change
echo "Verifying the change..."
grep -F "Exec=" "$DESKTOP_FILE" | grep -- "--unique" && {
  echo "Error: --unique still found in $DESKTOP_FILE. Aborting."
  exit 1
} || echo "Success: --unique removed from $DESKTOP_FILE."

# Step 4: Create an APT hook to reapply the sed command after upgrades
echo "Creating APT hook in $APT_HOOK..."
if test -f "$APT_HOOK"; then
  echo "before: $APT_HOOK"
  cat "$APT_HOOK"
fi
cat <<EOF > "$APT_HOOK"
DPkg::Post-Invoke {
  $(printf '%q ' "${SED_COMMAND[@]}") || true;
};
EOF
if test -f "$APT_HOOK"; then
  echo "after: $APT_HOOK"
  cat "$APT_HOOK"
fi

exit 0

# Step 5: Refresh the desktop database
echo "Refreshing the desktop database..."
update-desktop-database /usr/share/applications/

# Step 6: Verify the desktop database is updated
echo "Verifying desktop entry..."
grep -F "Exec=" "$DESKTOP_FILE"

echo "Setup complete! The --unique option has been removed and the APT hook is in place."
