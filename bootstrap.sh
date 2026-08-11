#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$ROOT/packages.txt"
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/bootstrapper/backups"
MANAGED_DIRECTORIES=(
  "$HOME/repos/peppeppa"
  "$HOME/repos/var"
  "$HOME/repos/eternalpingdom"
)

MODE="${1:-check}"
DEVIATIONS=0
CHANGES=0
CONFIG_CHANGED=0

usage() {
  cat <<'USAGE'
Usage: ./bootstrap.sh [check|diff|apply]

  check  Show missing/different files and packages (default)
  diff   Show file diffs and missing packages
  apply  Restore managed files and install missing packages
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

section() {
  printf '\n==> %s\n' "$1"
}

trim() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  printf '%s' "$value"
}

check_directories() {
  local directory

  for directory in "${MANAGED_DIRECTORIES[@]}"; do
    if [[ -d "$directory" ]]; then
      printf '  ✓ %s\n' "$directory"
    else
      printf '  ✗ %s missing\n' "$directory"
      ((DEVIATIONS += 1))
    fi
  done
}

apply_directories() {
  local directory

  for directory in "${MANAGED_DIRECTORIES[@]}"; do
    if [[ -d "$directory" ]]; then
      printf '  ✓ %s\n' "$directory"
      continue
    fi

    mkdir -p -- "$directory"

    printf '  → %s created\n' "$directory"
    ((CHANGES += 1))
  done
}

handle_directories() {
  section "Directories"

  case "$MODE" in
  check | diff)
    check_directories
    ;;
  apply)
    apply_directories
    ;;
  esac
}

is_omarchy() {
  if command -v omarchy >/dev/null 2>&1; then
    return 0
  fi

  if [[ -d "/usr/share/omarchy" ]]; then
    return 0
  fi

  if [[ -d "$HOME/.local/share/omarchy" ]]; then
    return 0
  fi

  return 1
}

managed_source() {
  [[ -s "$1" ]]
}

file_status() {
  local label="$1"
  local source="$2"
  local target="$3"

  if ! managed_source "$source"; then
    printf '  - %-24s unmanaged (source is empty)\n' "$label"
    return 0
  fi

  if [[ ! -e "$target" ]]; then
    printf '  ✗ %-24s missing\n' "$label"
    ((DEVIATIONS += 1))
    return 1
  fi

  if cmp -s -- "$source" "$target"; then
    printf '  ✓ %-24s ok\n' "$label"
    return 0
  fi

  printf '  ✗ %-24s differs\n' "$label"
  ((DEVIATIONS += 1))
  return 1
}

show_file_diff() {
  local label="$1"
  local source="$2"
  local target="$3"

  if ! managed_source "$source"; then
    printf '  - %-24s unmanaged (source is empty)\n' "$label"
    return 0
  fi

  if [[ ! -e "$target" ]]; then
    diff -u \
      --label "$target (missing)" \
      --label "$source (desired)" \
      /dev/null "$source" || true

    ((DEVIATIONS += 1))
    return 0
  fi

  if cmp -s -- "$source" "$target"; then
    printf '  ✓ %-24s ok\n' "$label"
    return 0
  fi

  printf '\n# %s\n' "$label"

  diff -u \
    --label "$target (current)" \
    --label "$source (desired)" \
    "$target" "$source" || true

  ((DEVIATIONS += 1))
}

backup_target() {
  local target="$1"
  local timestamp
  local backup

  [[ -e "$target" ]] || return 0

  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup="$BACKUP_ROOT/$timestamp${target#$HOME}"

  mkdir -p -- "$(dirname -- "$backup")"
  cp -a -- "$target" "$backup"

  printf '    backup: %s\n' "$backup"
}

apply_file() {
  local label="$1"
  local source="$2"
  local target="$3"

  if ! managed_source "$source"; then
    printf '  - %-24s unmanaged (source is empty)\n' "$label"
    return 0
  fi

  if [[ -e "$target" ]] && cmp -s -- "$source" "$target"; then
    printf '  ✓ %-24s ok\n' "$label"
    return 0
  fi

  if [[ -e "$target" ]]; then
    backup_target "$target"
    printf '  → %-24s restore\n' "$label"
  else
    printf '  → %-24s create\n' "$label"
  fi

  install -Dm644 -- "$source" "$target"

  ((CHANGES += 1))
  CONFIG_CHANGED=1
}

read_packages() {
  local line
  local package

  [[ -f "$PACKAGES_FILE" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip comments.
    line="${line%%#*}"

    package="$(trim "$line")"

    # Ignore empty lines.
    [[ -n "$package" ]] || continue

    printf '%s\n' "$package"
  done <"$PACKAGES_FILE"
}

package_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

collect_missing_packages() {
  local package

  MISSING_PACKAGES=()

  while IFS= read -r package; do
    [[ -n "$package" ]] || continue

    if ! package_installed "$package"; then
      MISSING_PACKAGES+=("$package")
    fi
  done < <(read_packages)
}

check_packages() {
  local package

  if [[ ! -s "$PACKAGES_FILE" ]]; then
    echo "  - packages.txt unmanaged (empty)"
    return 0
  fi

  if ! command -v pacman >/dev/null 2>&1; then
    echo "  ! pacman not found; package management is not supported on this system yet"
    return 0
  fi

  collect_missing_packages

  if ((${#MISSING_PACKAGES[@]} == 0)); then
    echo "  ✓ all packages installed"
    return 0
  fi

  for package in "${MISSING_PACKAGES[@]}"; do
    printf '  ✗ %-24s missing\n' "$package"
    ((DEVIATIONS += 1))
  done
}

apply_packages() {
  if [[ ! -s "$PACKAGES_FILE" ]]; then
    echo "  - packages.txt unmanaged (empty)"
    return 0
  fi

  if ! command -v pacman >/dev/null 2>&1; then
    echo "Package installation currently supports Arch/pacman only." >&2
    exit 1
  fi

  collect_missing_packages

  if ((${#MISSING_PACKAGES[@]} == 0)); then
    echo "  ✓ all packages installed"
    return 0
  fi

  printf '  → installing: %s\n' "${MISSING_PACKAGES[*]}"

  if command -v omarchy >/dev/null 2>&1; then
    omarchy pkg add "${MISSING_PACKAGES[@]}"
  else
    sudo pacman -S --needed --noconfirm "${MISSING_PACKAGES[@]}"
  fi

  CHANGES=$((CHANGES + ${#MISSING_PACKAGES[@]}))
}

handle_config() {
  local action="$1"
  local handler

  case "$action" in
  check)
    handler=file_status
    ;;
  diff)
    handler=show_file_diff
    ;;
  apply)
    handler=apply_file
    ;;
  esac

  section "Configuration"

  if is_omarchy; then
    "$handler" \
      "Omarchy bindings" \
      "$ROOT/config/omarchy/bindings.lua" \
      "$HOME/.config/hypr/bindings.lua" || true
    "$handler" \
      "Omarchy input" \
      "$ROOT/config/omarchy/input.lua" \
      "$HOME/.config/hypr/input.lua" || true
  else
    echo "  - Omarchy bindings skipped (Omarchy not detected)"
  fi

  "$handler" \
    "Neovim keymaps" \
    "$ROOT/config/nvim/keymaps.lua" \
    "$HOME/.config/nvim/lua/config/keymaps.lua" || true
}

handle_packages() {
  section "Packages"

  case "$MODE" in
  check | diff)
    check_packages
    ;;
  apply)
    apply_packages
    ;;
  esac
}

reload_hyprland() {
  [[ "$MODE" == "apply" ]] || return 0
  ((CONFIG_CHANGED > 0)) || return 0

  command -v hyprctl >/dev/null 2>&1 || return 0
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 0

  section "Hyprland"

  if hyprctl reload >/dev/null; then
    echo "  ✓ reloaded"
  else
    echo "  ! reload failed; check the Hyprland configuration" >&2
  fi
}

handle_directories
handle_config "$MODE"
handle_packages
reload_hyprland

section "Result"

case "$MODE" in
check | diff)
  if ((DEVIATIONS == 0)); then
    echo "  ✓ no deviations"
    exit 0
  fi

  printf '  %d deviation(s) found\n' "$DEVIATIONS"
  exit 1
  ;;

apply)
  if ((CHANGES == 0)); then
    echo "  ✓ already up to date"
  else
    printf '  ✓ %d change(s) applied\n' "$CHANGES"
  fi
  ;;
esac
