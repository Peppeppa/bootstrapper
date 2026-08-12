#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$ROOT/packages.txt"
MODE="${1:-apply}"

REPOS_ROOT="$HOME/repos/peppeppa"
DOTFILES_DIR="$REPOS_ROOT/dotfiles-stow"
STOW_MANIFEST="$DOTFILES_DIR/stow-packages.txt"
BITWARDEN_SOCKET="$HOME/.bitwarden-ssh-agent.sock"

MANAGED_DIRECTORIES=(
  "$HOME/repos/peppeppa"
  "$HOME/repos/var"
  "$HOME/repos/eternalpingdom"
)

PRIVATE_REPOS=(
  "dotfiles-stow|git@github.com:Peppeppa/dotfiles-stow.git|$REPOS_ROOT/dotfiles-stow"
  "wallpaper|git@github.com:Peppeppa/wallpaper.git|$REPOS_ROOT/wallpaper"
)

DEVIATIONS=0
CHANGES=0

case "$MODE" in
check | diff | apply) ;;
*)
  echo "Usage: $0 [check|diff|apply]"
  exit 2
  ;;
esac

section() {
  echo
  echo "==> $1"
}

read_list() {
  sed \
    -e 's/#.*$//' \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//' \
    -e '/^$/d' \
    "$1"
}

# -----------------------------------------------------------------------------
# Directories
# -----------------------------------------------------------------------------

handle_directories() {
  section "Directories"

  local dir
  for dir in "${MANAGED_DIRECTORIES[@]}"; do
    if [[ -d "$dir" ]]; then
      printf '  ✓ %s\n' "$dir"
    elif [[ "$MODE" == "apply" ]]; then
      mkdir -p "$dir"
      printf '  → created %s\n' "$dir"
      ((CHANGES += 1))
    else
      printf '  ✗ missing %s\n' "$dir"
      ((DEVIATIONS += 1))
    fi
  done
}

# -----------------------------------------------------------------------------
# Packages
# -----------------------------------------------------------------------------

handle_packages() {
  section "Packages"

  if [[ ! -f "$PACKAGES_FILE" ]]; then
    echo "  ! missing $PACKAGES_FILE"
    return 1
  fi

  local packages=()
  local missing=()
  local package

  mapfile -t packages < <(read_list "$PACKAGES_FILE")

  for package in "${packages[@]}"; do
    if pacman -Q "$package" >/dev/null 2>&1; then
      printf '  ✓ %s\n' "$package"
    else
      printf '  ✗ %s\n' "$package"
      missing+=("$package")
    fi
  done

  ((${#missing[@]} == 0)) && return

  if [[ "$MODE" != "apply" ]]; then
    ((DEVIATIONS += ${#missing[@]}))
    return
  fi

  echo
  printf '  → installing %s\n' "${missing[*]}"
  sudo pacman -S --needed --noconfirm "${missing[@]}"
  ((CHANGES += ${#missing[@]}))
}

# -----------------------------------------------------------------------------
# Bitwarden CLI
# -----------------------------------------------------------------------------

is_bitwarden_cloud() {
  local server="$1"

  [[ -z "$server" ]] ||
    [[ "$server" == "https://vault.bitwarden.com" ]] ||
    [[ "$server" == "https://vault.bitwarden.eu" ]]
}

handle_bitwarden_cli() {
  section "Bitwarden CLI"

  if ! command -v bw >/dev/null 2>&1; then
    echo "  ✗ bw not installed"
    [[ "$MODE" == "apply" ]] || ((DEVIATIONS += 1))
    return
  fi

  local current_server
  current_server="$(bw config server 2>/dev/null || true)"

  if ! is_bitwarden_cloud "$current_server"; then
    printf '  ✓ server: %s\n' "$current_server"
    return
  fi

  if [[ "$MODE" != "apply" ]]; then
    echo "  ✗ self-hosted server not configured"
    ((DEVIATIONS += 1))
    return
  fi

  local server
  echo
  printf 'Self-hosted Bitwarden URL (https://...): ' >/dev/tty
  IFS= read -r server </dev/tty

  [[ -n "$server" ]] || {
    echo "  - skipped"
    return
  }

  [[ "$server" == https://* ]] || {
    echo "  ! URL must start with https://"
    return 1
  }

  bw logout >/dev/null 2>&1 || true
  bw config server "$server" >/dev/null

  printf '  ✓ configured: %s\n' "$server"
  ((CHANGES += 1))
}

# -----------------------------------------------------------------------------
# Bitwarden SSH Agent
# -----------------------------------------------------------------------------

bitwarden_agent_ready() {
  [[ -S "$BITWARDEN_SOCKET" ]] &&
    SSH_AUTH_SOCK="$BITWARDEN_SOCKET" ssh-add -L >/dev/null 2>&1
}

ensure_bitwarden_agent() {
  section "Bitwarden SSH Agent"

  if bitwarden_agent_ready; then
    export SSH_AUTH_SOCK="$BITWARDEN_SOCKET"
    echo "  ✓ ready"
    return
  fi

  if [[ "$MODE" != "apply" ]]; then
    echo "  - currently unavailable"
    return 1
  fi

  command -v ssh-add >/dev/null 2>&1 || {
    echo "  ! ssh-add not installed"
    return 1
  }

  if command -v bitwarden-desktop >/dev/null 2>&1; then
    bitwarden-desktop >/dev/null 2>&1 &
  fi

  echo
  echo "Open Bitwarden Desktop and:"
  echo "  1. select your self-hosted server"
  echo "  2. log in / unlock the vault"
  echo "  3. enable Settings -> SSH Agent"
  echo "  4. make your SSH key available to the agent"
  echo

  local answer

  until bitwarden_agent_ready; do
    printf 'Press Enter when ready, or q to abort: ' >/dev/tty
    IFS= read -r answer </dev/tty

    if [[ "${answer,,}" == "q" ]]; then
      echo "  ! SSH Agent setup aborted"
      return 1
    fi

    bitwarden_agent_ready || echo "  ✗ agent not ready yet"
  done

  export SSH_AUTH_SOCK="$BITWARDEN_SOCKET"
  echo "  ✓ ready"
}

# -----------------------------------------------------------------------------
# Private repositories
# -----------------------------------------------------------------------------

sync_repo() {
  local name="$1"
  local url="$2"
  local dir="$3"

  if [[ -d "$dir/.git" ]]; then
    printf '  → update %s\n' "$name"
    git -C "$dir" pull --ff-only
  elif [[ -e "$dir" ]]; then
    echo "  ! $dir exists but is not a Git repository"
    return 1
  else
    printf '  → clone %s\n' "$name"
    git clone "$url" "$dir"
  fi
}

handle_private_repos() {
  section "Private repositories"

  local entry
  local name
  local url
  local dir

  if [[ "$MODE" == "apply" ]]; then
    ensure_bitwarden_agent
    mkdir -p "$REPOS_ROOT"

    for entry in "${PRIVATE_REPOS[@]}"; do
      IFS='|' read -r name url dir <<<"$entry"
      sync_repo "$name" "$url" "$dir"
    done

    return
  fi

  for entry in "${PRIVATE_REPOS[@]}"; do
    IFS='|' read -r name url dir <<<"$entry"

    if [[ -d "$dir/.git" ]]; then
      printf '  ✓ %s\n' "$name"

      if [[ "$MODE" == "diff" ]]; then
        git -C "$dir" status --short
      fi
    else
      printf '  ✗ %s missing\n' "$name"
      ((DEVIATIONS += 1))
    fi
  done
}

# -----------------------------------------------------------------------------
# Dotfiles / GNU Stow
# -----------------------------------------------------------------------------

validate_dotfiles() {
  [[ -d "$DOTFILES_DIR/.git" ]] || {
    echo "  ! dotfiles-stow repository missing"
    return 1
  }

  [[ -f "$STOW_MANIFEST" ]] || {
    echo "  ! missing $STOW_MANIFEST"
    return 1
  }

  local packages=()
  local package

  mapfile -t packages < <(read_list "$STOW_MANIFEST")

  ((${#packages[@]} > 0)) || {
    echo "  ! stow manifest is empty"
    return 1
  }

  for package in "${packages[@]}"; do
    [[ -d "$DOTFILES_DIR/$package" ]] || {
      echo "  ! missing stow package: $package"
      return 1
    }
  done
}

stow_package() {
  local package="$1"

  # Adopt existing Omarchy files, then immediately restore the committed
  # dotfile. Git stays the source of truth while Stow owns the target.
  if ! stow \
    --dir="$DOTFILES_DIR" \
    --target="$HOME" \
    --adopt \
    --restow \
    "$package"; then

    git -C "$DOTFILES_DIR" restore \
      --worktree \
      -- "$package" >/dev/null 2>&1 || true

    return 1
  fi

  git -C "$DOTFILES_DIR" restore \
    --worktree \
    -- "$package"
}

handle_dotfiles() {
  section "Dotfiles"

  if ! validate_dotfiles; then
    [[ "$MODE" == "apply" ]] || ((DEVIATIONS += 1))
    return
  fi

  local packages=()
  local package

  mapfile -t packages < <(read_list "$STOW_MANIFEST")

  if [[ "$MODE" == "apply" ]]; then
    [[ -z "$(git -C "$DOTFILES_DIR" status --porcelain)" ]] || {
      echo "  ! dotfiles repository has local changes"
      echo "    commit or stash them before apply"
      return 1
    }

    for package in "${packages[@]}"; do
      printf '  → stow %s\n' "$package"
      stow_package "$package"
    done

    ((CHANGES += 1))
    return
  fi

  for package in "${packages[@]}"; do
    if stow \
      --dir="$DOTFILES_DIR" \
      --target="$HOME" \
      --no \
      --restow \
      "$package" >/dev/null 2>&1; then

      printf '  ✓ %s\n' "$package"
    else
      printf '  ✗ %s has conflicts\n' "$package"
      ((DEVIATIONS += 1))

      if [[ "$MODE" == "diff" ]]; then
        stow \
          --dir="$DOTFILES_DIR" \
          --target="$HOME" \
          --no \
          --verbose=2 \
          --restow \
          "$package" || true
      fi
    fi
  done
}

# -----------------------------------------------------------------------------
# Hyprland
# -----------------------------------------------------------------------------

reload_hyprland() {
  [[ "$MODE" == "apply" ]] || return
  command -v hyprctl >/dev/null 2>&1 || return
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return

  section "Hyprland"

  if hyprctl reload >/dev/null; then
    echo "  ✓ reloaded"
  else
    echo "  ! reload failed"
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

handle_directories
handle_packages
handle_bitwarden_cli
handle_private_repos
handle_dotfiles
reload_hyprland

section "Summary"

if [[ "$MODE" == "apply" ]]; then
  echo "Changes: $CHANGES"
  exit 0
fi

if ((DEVIATIONS > 0)); then
  echo "Deviations: $DEVIATIONS"
  exit 1
fi

echo "Everything looks good."
