#!/bin/bash

die() { printf %s "${@+$@$'\n'}" 1>&2 ; exit 1 ; }
see() ( { set -x; } 2>/dev/null ; "$@" )

YARNLOCKFILE='yarn.lock'
test -f "$YARNLOCKFILE" || die "no $YARNLOCKFILE in cwd"

# Set variables
PACKAGE_NAME="@openai/realtime-api-beta"
REPO="openai/openai-realtime-api-beta"
PACKAGE_ENTRY="\"${PACKAGE_NAME}@github:${REPO}\":"

# Extract the installed commit hash from yarn.lock
INSTALLED_COMMIT=$(grep -A 2 "$PACKAGE_ENTRY" "$YARNLOCKFILE" | \
                   grep "resolved" | sed -E 's|.*/tar.gz/([a-f0-9]+).*|\1|')

# Get the latest commit hash from the default branch (HEAD) of the GitHub repository
LATEST_COMMIT=$(git ls-remote "https://github.com/${REPO}.git" HEAD | awk '{print $1}')

# Output installed and latest commit hashes
echo "Installed commit: $INSTALLED_COMMIT"
echo "Latest commit:    $LATEST_COMMIT"

test -n "$INSTALLED_COMMIT" || die "INSTALLED_COMMIT is blank; fix this script!"

# Check if the two hashes are different
if [ "$INSTALLED_COMMIT" == "$LATEST_COMMIT" ]; then
  echo "?  Package $PACKAGE_NAME is up-to-date."
  exit 0
fi

# Use the GitHub API to compare the two commits
COMMITS_BEHIND=$(curl -s "https://api.github.com/repos/${REPO}/compare/${INSTALLED_COMMIT}...${LATEST_COMMIT}" | \
                 jq '.total_commits')

# Check if the API call was successful
if [ "$COMMITS_BEHIND" == "null" ]; then
  echo "? Unable to determine the number of commits behind."
  exit 1
fi

# Display the result
echo "? Update available: $PACKAGE_NAME is $COMMITS_BEHIND commit(s) behind."
echo "to upgrade, run: yarn upgrade @openai/realtime-api-beta"
echo "commits: https://github.com/openai/openai-realtime-api-beta/commits/main/"
