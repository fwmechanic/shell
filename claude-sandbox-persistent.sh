#!/bin/bash

# Claude Code Sandbox Runner (Persistent Container)
# Uses a named container that persists between runs, avoiding OAuth re-auth issues.
#
# Usage: ./claude-sandbox-persistent.sh <plan-file> <legacy-project-dir> <new-repo-dir>

die()  { printf %s "${@+$@$'\n'}" 1>&2 ; exit 1 ; }
see()  ( { set -x; } 2>/dev/null ; "$@" )
have() { command -v "$1" &>/dev/null; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="claude-sandbox"
IMAGE_TAG="latest"

usage() {
    cat <<EOF
Usage: $0 <plan-file> <legacy-project-dir> <new-repo-dir>

Arguments:
  plan-file          Path to the plan/spec file (mounted read-only)
  legacy-project-dir Path to legacy codebase to reference (mounted read-only)
  new-repo-dir       Path to new repo directory (created if absent, mounted read-write)

Authentication:
  On first run, Claude will prompt for OAuth login (opens browser / shows URL).
  Auth persists in the container between runs (no re-auth needed).

Container Management:
  Container name is derived from the new-repo-dir absolute path.
  Use 'podman rm <container-name>' to remove and force re-auth.

Example:
  $0 ./plan.md ./legacy-app ./new-app
EOF
    exit 1
}

# Check prereqs
have podman || die "missing needed prog: podman"

# Check arguments
[[ $# -ge 3 ]] || usage

PLAN_FILE="$1"
LEGACY_DIR="$2"
NEW_REPO_DIR="$3"

# Validate inputs
[[ -f "$PLAN_FILE" ]]    || die "Plan file not found: $PLAN_FILE"
[[ -d "$LEGACY_DIR" ]]   || die "Legacy project directory not found: $LEGACY_DIR"

# Initialize new repo dir if absent or empty
if [[ ! -d "$NEW_REPO_DIR" ]]; then
    echo "Creating new repo directory: $NEW_REPO_DIR"
    mkdir -p "$NEW_REPO_DIR" || die "Failed to create $NEW_REPO_DIR"
fi

if [[ -z "$(ls -A "$NEW_REPO_DIR" 2>/dev/null)" ]]; then
    echo "Initializing empty repo directory..."
    git -C "$NEW_REPO_DIR" init || die "Failed to git init in $NEW_REPO_DIR"
fi

# Resolve to absolute paths
PLAN_FILE="$(cd "$(dirname "$PLAN_FILE")" && pwd)/$(basename "$PLAN_FILE")"
LEGACY_DIR="$(cd "$LEGACY_DIR" && pwd)"
NEW_REPO_DIR="$(cd "$NEW_REPO_DIR" && pwd)"

# Track legacy repo HEAD for detecting changes between runs
DIFFS_DIR="$(dirname "$NEW_REPO_DIR")/.current-impl-diffs-$(basename "$NEW_REPO_DIR")"
[[ -d "$DIFFS_DIR" ]] || mkdir -p "$DIFFS_DIR"

LEGACY_HEAD_FILE="$DIFFS_DIR/legacy-head"
LEGACY_CURRENT_HEAD=$(git -C "$LEGACY_DIR" rev-parse HEAD 2>/dev/null || echo "")
if [[ -n "$LEGACY_CURRENT_HEAD" ]]; then
    if [[ -f "$LEGACY_HEAD_FILE" ]]; then
        LEGACY_PREV_HEAD=$(cat "$LEGACY_HEAD_FILE")
        if [[ "$LEGACY_PREV_HEAD" != "$LEGACY_CURRENT_HEAD" ]]; then
            DIFF_FILENAME="legacy-${LEGACY_PREV_HEAD:0:8}..${LEGACY_CURRENT_HEAD:0:8}.diff"
            DIFF_FILE="$DIFFS_DIR/$DIFF_FILENAME"
            {
                echo "# Legacy repo changes: $LEGACY_PREV_HEAD -> $LEGACY_CURRENT_HEAD"
                echo ""
                echo "## Commits"
                git -C "$LEGACY_DIR" --no-pager log --oneline "${LEGACY_PREV_HEAD}..${LEGACY_CURRENT_HEAD}" 2>/dev/null || true
                echo ""
                echo "## Diff"
                git -C "$LEGACY_DIR" --no-pager diff "${LEGACY_PREV_HEAD}..${LEGACY_CURRENT_HEAD}" 2>/dev/null || true
            } > "$DIFF_FILE"
            # Symlink with stable name for Claude to find
            ln -sf "$DIFF_FILENAME" "$DIFFS_DIR/current-impl-changes.diff"
            echo "Legacy repo changed: wrote $DIFF_FILE"
        fi
    fi
    echo "$LEGACY_CURRENT_HEAD" > "$LEGACY_HEAD_FILE"
fi

# Container name from new-repo absolute path (strip /home/<user>/, replace / with -)
CONTAINER_NAME="claude-$(echo "$NEW_REPO_DIR" | sed 's|^/home/[^/]*/||; s|/|-|g')"

cat <<EOF
=== Claude Sandbox Configuration (Persistent) ===
Plan file:      $PLAN_FILE -> /workspace/plan-for-claude-to-implement.md (ro)
Legacy project: $LEGACY_DIR -> /workspace/current-implementation (ro)
New repo:       $NEW_REPO_DIR -> /workspace/new-implementation-repo (rw)
Diffs dir:      $DIFFS_DIR -> /workspace/.current-impl-diffs (ro)
Container:      $CONTAINER_NAME
==================================================
EOF

# Build image if needed (uses cache, fast if unchanged)
build_image() {
    echo "Building/verifying container image..."

    podman build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f - "$SCRIPT_DIR" <<'DOCKERFILE'
FROM node:20-slim

# Install system dependencies Claude Code commonly needs
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ripgrep \
    curl \
    jq \
    ca-certificates \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm globally
RUN corepack enable && corepack prepare pnpm@latest --activate

# Entrypoint script that installs/updates Claude Code on every container start
RUN printf '#!/bin/bash\necho "Installing latest claude-code..."\nnpm install -g @anthropic-ai/claude-code@latest\nexec "$@"\n' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Create home directory for non-root user (used with --userns=keep-id)
RUN mkdir -p /home/claude && chmod 777 /home/claude

WORKDIR /workspace

CMD ["claude", "--dangerously-skip-permissions"]
DOCKERFILE

    [[ $? -eq 0 ]] || die "Failed to build container image"
    echo "Image ready: ${IMAGE_NAME}:${IMAGE_TAG}"
}

build_image

CONTAINER_HOME="/home/claude"

# Check if container exists
if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
    echo "Using existing container: $CONTAINER_NAME"

    # Check if it's running
    if podman ps -q -f "name=$CONTAINER_NAME" | grep -q .; then
        echo "Container is already running. Attaching..."
        see podman attach "$CONTAINER_NAME"
    else
        echo "Starting stopped container..."
        see podman start -ai "$CONTAINER_NAME"
    fi
else
    echo "Creating new container: $CONTAINER_NAME"

    see podman run \
        -it \
        --name "$CONTAINER_NAME" \
        --userns=keep-id \
        -e "HOME=${CONTAINER_HOME}" \
        -v "${PLAN_FILE}:/workspace/plan-for-claude-to-implement.md:ro" \
        -v "${LEGACY_DIR}:/workspace/current-implementation:ro" \
        -v "${NEW_REPO_DIR}:/workspace/new-implementation-repo:rw" \
        -v "${DIFFS_DIR}:/workspace/.current-impl-diffs:ro" \
        -w "/workspace" \
        ${IMAGE_NAME}:${IMAGE_TAG}
fi
