#!/usr/bin/env bash
# Bootstrap uninstaller for claude-now-context.
# Downloads the CLI and runs it with --uninstall. For users without Homebrew.
# Pass "project" as the first arg to target ./.claude/settings.json instead.

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/pereljon/claude-now-context/main"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

curl -fsSL "${REPO_RAW}/claude-now-context" > "$TMP"
chmod +x "$TMP"
exec "$TMP" --uninstall "$@"
