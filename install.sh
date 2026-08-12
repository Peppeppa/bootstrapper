#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/Peppeppa/bootstrapper.git"
INSTALL_DIR="${BOOTSTRAPPER_HOME:-$HOME/.local/share/bootstrapper}"
MODE="${1:-apply}"

case "$MODE" in
check | diff | apply)
  ;;
*)
  echo "Usage: install.sh [check|diff|apply]"
  exit 2
  ;;
esac

if ! command -v git >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm git
fi

if [[ -d "$INSTALL_DIR/.git" ]]; then
  git -C "$INSTALL_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

exec "$INSTALL_DIR/bootstrap.sh" "$MODE"
