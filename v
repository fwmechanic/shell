#!/usr/bin/env bash

# start VS Code in the cwd (and block the terminal)
# not yet sure if blocking is a good idea; we'll see?

die() { printf %s "${@+$@$'\n'}" 1>&2 ; exit 1 ; }
see() ( { set -x; } 2>/dev/null ; "$@" )



echo "close VS Code to continue..."
see code --wait .  # the trailing '.' is significant
