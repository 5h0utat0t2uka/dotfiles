#!/usr/bin/env bash
set -euo pipefail
# Requires: log.sh for run/capture/die

is_determinate_nix() {
  nix --version 2>/dev/null | rg -q 'Determinate Nix'
}

ensure_nix_present() {
  command -v nix >/dev/null 2>&1 || return 1
  return 0
}

install_determinate_nix() {
  # Intentionally disabled for macOS bootstrap stability.
  # Do not run the script installer from automation.
  die "Nix is not installed. On macOS, install Determinate Nix via Determinate.pkg, then re-run ./scripts/setup.sh"
}

darwin_switch_first_time() {
  # Usage: darwin_switch_first_time <flake_dir> <hostkey>
  local flake_dir="$1"
  local hostkey="$2"
  run sudo nix run github:nix-darwin/nix-darwin -- switch --flake "${flake_dir}#${hostkey}"
}

darwin_switch_normal() {
  # Usage: darwin_switch_normal <flake_dir> <hostkey>
  local flake_dir="$1"
  local hostkey="$2"
  if command -v darwin-rebuild >/dev/null 2>&1; then
    run sudo darwin-rebuild switch --flake "${flake_dir}#${hostkey}"
  else
    run sudo nix run github:nix-darwin/nix-darwin -- switch --flake "${flake_dir}#${hostkey}"
  fi
}

load_nix_profile() {
  # Determinate / multi-user nix typical locations
  if [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  elif [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
  fi
}
