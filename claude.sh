#!/usr/bin/env bash
# ABOUTME: Launches Claude Code against the local LiteLLM proxy.
# ABOUTME: Reads the proxy master key from .env so no secret is committed.

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$script_dir/.env" ]; then
  echo "claude.sh: .env not found - run 'make install' first" >&2
  exit 1
fi

set -a
. "$script_dir/.env"
set +a

ANTHROPIC_AUTH_TOKEN="$LITELLM_MASTER_KEY" \
ANTHROPIC_BASE_URL="http://localhost:${PORT:-4000}" \
ANTHROPIC_MODEL=claude-sonnet-5 \
ANTHROPIC_SMALL_FAST_MODEL=claude-haiku-4-5 \
  exec claude "$@"
