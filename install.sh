#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/Peppeppa/bootstrapper.git"
INSTALL_DIR="${BOOTSTRAPPER_HOME:-$HOME/.local/share/bootstrapper}"
MODE="${1:-apply}"

usage() {
  cat <<'USAGE'
Usage:
  install.sh [check|diff|apply]

Default:
  apply
USAGE
}

case "$MODE" in
check | diff | apply) ;;
-h | --help | help)
  usage
  exit 0
  ;;
*)
  echo "Unknown mode: $MODE" >&2
  usage >&2
  exit 2
  ;;
esac

echo
echo "==> Bootstrapper"

# Git is the only dependency we need after curl.
if ! command -v git >/dev/null 2>&1; then
  echo "==> Installing git"

  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm git
  else
    echo "Cannot install git automatically on this system." >&2
    exit 1
  fi
fi

# Protect against accidentally overwriting an unrelated directory.
if [[ -e "$INSTALL_DIR" && ! -d "$INSTALL_DIR/.git" ]]; then
  echo "Install directory already exists but is not a Git repository:" >&2
  echo "  $INSTALL_DIR" >&2
  exit 1
fi

if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo "==> Updating repository"

  git -C "$INSTALL_DIR" pull --ff-only
else
  echo "==> Cloning repository"

  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

echo
echo "==> Running bootstrapper: $MODE"

exec "$INSTALL_DIR/bootstrap.sh" "$MODE"
