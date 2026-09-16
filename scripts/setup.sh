#!/bin/bash
# Apple Silicon bootstrap; compatible with macOS /bin/bash (3.2).
# See docs/setup.md. Never source the user's shell configuration here.
# Nix and jq expressions below deliberately contain literal dollar signs.
# shellcheck disable=SC2016
set +x
set -Eeuo pipefail
umask 077

STAGE=arguments
WORK_DIR=
IDENTITY_TEMP=
LOCK_DIR=
MODE=check
MODE_SET=0
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
FLAKE_DIR="$REPO_DIR/nix"
CHEZMOI_BACKUP=
SOPS_BACKUP=

log() { printf '%s\n' "==> $*"; }
die() { printf >&2 'ERROR [%s]: %s\n' "$STAGE" "$*"; exit 1; }

cleanup() {
  local result=$?
  trap - EXIT
  [[ -z "$IDENTITY_TEMP" ]] || /bin/rm -f -- "$IDENTITY_TEMP"
  # Only directories created by this invocation are removed.
  [[ -z "$WORK_DIR" ]] || /bin/rm -rf -- "$WORK_DIR"
  [[ -z "$LOCK_DIR" ]] || /bin/rmdir -- "$LOCK_DIR"
  exit "$result"
}
trap cleanup EXIT
trap 'printf >&2 "ERROR [%s]: failed at line %s (exit %s).\n" "$STAGE" "$LINENO" "$?"' ERR
trap 'exit 130' INT
trap 'exit 143' TERM

usage() {
  cat <<'USAGE'
Usage: ./scripts/setup.sh [--check | --apply]
                          [--chezmoi-backup /absolute/path/to/key.age]
                          [--sops-backup /absolute/path/to/key.age]

  --check   Local prerequisite checks only (default). No Nix evaluation,
            downloads, decryption, sudo, or destination writes.
  --apply   Validate, recover identities, build and apply the locked config.
            Run from a terminal as the target user, not through sudo.

Backup paths are required only when the corresponding identity is missing.
Download the files from iCloud Drive first. PINs/passphrases are never arguments.
There is no --dry-run, --force, --json, or --log mode. See docs/setup.md.
USAGE
}

parse_args() {
  while (( $# )); do
    case "$1" in
      --check|--apply)
        (( MODE_SET == 0 )) || die "Choose exactly one mode."
        MODE="${1#--}"; MODE_SET=1; shift ;;
      --chezmoi-backup|--sops-backup)
        [[ $# -ge 2 && "$2" == /* ]] || die "$1 requires an absolute file path."
        if [[ "$1" == --chezmoi-backup ]]; then CHEZMOI_BACKUP="$2"; else SOPS_BACKUP="$2"; fi
        shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown argument: $1" ;;
    esac
  done
}

# Reject symlinks throughout sensitive destination paths, including dangling ones.
check_path() {
  local path="$1"
  while [[ "$path" != / ]]; do
    [[ ! -L "$path" ]] || die "Symlink in destination path: $path"
    if [[ -e "$path" ]]; then
      [[ -O "$path" ]] || die "Destination is not owned by the current user: $path"
    fi
    [[ "$path" != "$HOME" ]] || break
    path="${path%/*}"
    [[ -n "$path" ]] || break
  done
}

check_identity_input() {
  local target="$1" backup="$2" option="$3"
  check_path "$target"
  if [[ -e "$target" ]]; then
    [[ -f "$target" && -r "$target" && -s "$target" ]] || die "Invalid identity file: $target"
    [[ "$(/usr/bin/stat -f '%Lp' "$target")" == 600 ]] || die "Set identity permissions to 600: $target"
    [[ "$(/usr/bin/stat -f '%l' "$target")" == 1 ]] || die "Identity must not have hard links: $target"
    log "Existing identity (cryptographic validation during --apply): $target"
  else
    [[ -n "$backup" ]] || die "Missing $target. Supply $option with the downloaded encrypted backup."
    [[ -f "$backup" && -r "$backup" && -s "$backup" ]] || die "Backup is missing, empty, or unreadable: $backup"
    log "Identity recovery required: $target"
  fi
}

assert_clean_source() {
  [[ "$(/usr/bin/git -C "$REPO_DIR" rev-parse HEAD)" == "$SOURCE_REV" ]] || die "Repository HEAD changed during setup."
  [[ -z "$(/usr/bin/git -C "$REPO_DIR" status --porcelain --untracked-files=normal)" ]] ||
    die "Review and commit repository changes before --apply; do not update the repository during setup."
}

preflight() {
  STAGE=preflight
  [[ "$(/usr/bin/uname -s)" == Darwin && "$(/usr/bin/uname -m)" == arm64 ]] ||
    die "Run natively on Apple Silicon macOS (not under Rosetta)."
  (( EUID != 0 )) || die "Run as your normal macOS user, without sudo."
  [[ -n "${HOME:-}" && "$HOME" == /* && -d "$HOME" ]] || die "HOME must be an existing absolute directory."
  USER_NAME="$(/usr/bin/id -un)"
  USER_ID="$(/usr/bin/id -u)"
  if ! /usr/bin/xcode-select -p >/dev/null 2>&1 || ! /usr/bin/xcrun --find clang >/dev/null 2>&1; then
    die "Install/select Command Line Tools or Xcode first: xcode-select --install"
  fi
  [[ "$(/usr/bin/git -C "$REPO_DIR" rev-parse --show-toplevel)" == "$REPO_DIR" ]] || die "Run the script from the dotfiles Git checkout."
  [[ "$REPO_DIR" == "$HOME/.local/share/chezmoi" ]] || die "Clone the repository into $HOME/.local/share/chezmoi."
  [[ -f "$FLAKE_DIR/flake.nix" && -f "$FLAKE_DIR/flake.lock" ]] || die "Missing flake.nix or flake.lock."
  SOURCE_REV="$(/usr/bin/git -C "$REPO_DIR" rev-parse HEAD)"
  HOST_KEY="$(/usr/sbin/scutil --get LocalHostName)" || die "Set LocalHostName to a configured host first."
  [[ "$HOST_KEY" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] || die "Invalid LocalHostName."
  [[ -f "$FLAKE_DIR/hosts/darwin/$HOST_KEY/identity.nix" && -f "$FLAKE_DIR/hosts/darwin/$HOST_KEY/default.nix" ]] ||
    die "No host definition for $HOST_KEY. Prepare and commit the new host before setup."

  # Use the installer profile even before a login shell configures PATH.
  NIX=/nix/var/nix/profiles/default/bin/nix
  [[ -x "$NIX" ]] || die "Install Determinate Nix using the official macOS package first."
  [[ "$("$NIX" --version)" == *'Determinate Nix'* ]] || die "This configuration requires Determinate Nix."
  /bin/launchctl print "gui/$USER_ID" >/dev/null 2>&1 || die "Log into the macOS desktop as $USER_NAME before setup (SOPS uses a user LaunchAgent)."
  export PATH="/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  [[ -z "${XDG_CONFIG_HOME:-}" || "$XDG_CONFIG_HOME" == "$HOME/.config" ]] || die "This configuration expects XDG_CONFIG_HOME=$HOME/.config."
  CHEZMOI_CONFIG="$HOME/.config/chezmoi/chezmoi.toml"
  CHEZMOI_KEY="$HOME/.config/chezmoi/age-key.txt"
  SOPS_KEY="$HOME/.config/sops/age/keys.txt"
  check_path "$CHEZMOI_CONFIG"
  check_identity_input "$CHEZMOI_KEY" "$CHEZMOI_BACKUP" --chezmoi-backup
  check_identity_input "$SOPS_KEY" "$SOPS_BACKUP" --sops-backup
  log "Host: $HOST_KEY / user: $USER_NAME / commit: $SOURCE_REV"
  if [[ "$MODE" == check ]]; then
    log "Local checks passed. Key contents, flake evaluation, /etc conflicts and builds are checked during --apply."
    log "--apply requires a clean committed checkout and an interactive terminal."
  else
    [[ -t 0 && -t 1 ]] || die "Use an interactive terminal; do not pipe setup output to a log."
    assert_clean_source
  fi
}

prepare_workdir() {
  STAGE=tools
  local lock_path="$REPO_DIR/.git/dotfiles-setup.lock"
  [[ -d "$REPO_DIR/.git" ]] || die "Use a normal clone, not a linked Git worktree."
  /bin/mkdir "$lock_path" 2>/dev/null || die "Another setup is running, or $lock_path remains after an interruption."
  LOCK_DIR="$lock_path"
  WORK_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/dotfiles-setup.XXXXXXXX")"
  log "Building bootstrap tools from flake.lock."
  "$NIX" build --no-update-lock-file --out-link "$WORK_DIR/tools" "$FLAKE_DIR#bootstrap-tools"
  TOOLS="$WORK_DIR/tools/bin"
  export PATH="$TOOLS:$PATH"
}

validate_configuration() {
  STAGE=configuration
  "$NIX" eval --json --file "$FLAKE_DIR/hosts/darwin/$HOST_KEY/identity.nix" > "$WORK_DIR/identity.json"
  "$TOOLS/jq" -e --arg user "$USER_NAME" --arg host "$HOST_KEY" --arg home "$HOME" --arg flake "$FLAKE_DIR" '
    .username == $user and .hostname == $host and .system == "aarch64-darwin"
    and .homeDirectory == $home and .flakeRoot == $flake
  ' "$WORK_DIR/identity.json" >/dev/null || die "identity.nix does not match this user, host, home or flake directory."
  "$NIX" eval --no-update-lock-file --json "$FLAKE_DIR#darwinConfigurations.$HOST_KEY.config" --apply '
    c: let u = c.system.primaryUser; h = c.home-manager.users.${u}; in {
      user = u; system = c.nixpkgs.hostPlatform.system; home = c.users.users.${u}.home;
      nixEnabled = c.nix.enable;
      shell = toString c.users.users.${u}.shell;
      ageKey = h.sops.age.keyFile;
      sopsFiles = builtins.attrValues (builtins.mapAttrs (_: s: toString s.sopsFile) h.sops.secrets);
      sopsOutputs = (builtins.map (s: { inherit (s) path mode; }) (builtins.attrValues h.sops.secrets))
        ++ (builtins.map (s: { inherit (s) path mode; }) (builtins.attrValues h.sops.templates));
      etc = builtins.map (f: { inherit (f) target knownSha256Hashes; })
        (builtins.filter (f: f.enable) (builtins.attrValues c.environment.etc));
      homebrew = { inherit (c.homebrew.onActivation) autoUpdate upgrade cleanup; };
    }
  ' > "$WORK_DIR/config.json"
  "$TOOLS/jq" -e --arg user "$USER_NAME" --arg home "$HOME" --arg key "$SOPS_KEY" '
    .user == $user and .home == $home and .system == "aarch64-darwin"
    and .nixEnabled == false and .ageKey == $key
  ' "$WORK_DIR/config.json" >/dev/null || die "Evaluated configuration does not match this machine or SOPS key path."

  # Generate the template in isolation; do not overwrite an existing config.
  cm --config "$WORK_DIR/chezmoi.toml" init
  cm --config "$WORK_DIR/chezmoi.toml" dump-config --format json > "$WORK_DIR/chezmoi.json"
  # Disable Git automation only for this invocation; keep the user's template.
  "$TOOLS/jq" '.git.autocommit = false | .git.autopush = false | .git.autoadd = false' \
    "$WORK_DIR/chezmoi.json" > "$WORK_DIR/chezmoi-runtime.json"
  CHEZMOI_RECIPIENT="$("$TOOLS/jq" -er '.age.recipient' "$WORK_DIR/chezmoi.json")"
  [[ "$CHEZMOI_RECIPIENT" =~ ^age1[0-9a-z]+$ ]] || die "Expected one native age recipient in the chezmoi template."
  "$TOOLS/jq" -e --arg key "$CHEZMOI_KEY" '
    .encryption == "age" and (.age.identity == $key or .age.identity == "~/.config/chezmoi/age-key.txt")
  ' "$WORK_DIR/chezmoi.json" >/dev/null || die "Unexpected chezmoi encryption configuration."
  if [[ -e "$CHEZMOI_CONFIG" ]]; then
    /usr/bin/cmp -s "$CHEZMOI_CONFIG" "$WORK_DIR/chezmoi.toml" ||
      die "Existing chezmoi.toml differs from the repository template. Review and run chezmoi init manually, then retry."
  fi
  # .sops.yaml is the source of truth for the current single-recipient policy.
  SOPS_RECIPIENT="$(/usr/bin/sed -n 's/^[[:space:]]*-[[:space:]]*\(age1[0-9a-z]*\)[[:space:]]*$/\1/p' "$REPO_DIR/.sops.yaml")"
  [[ "$SOPS_RECIPIENT" =~ ^age1[0-9a-z]+$ ]] || die "Expected exactly one native age recipient in .sops.yaml."
  [[ "$SOPS_RECIPIENT" != "$CHEZMOI_RECIPIENT" ]] || die "chezmoi and SOPS must use separate identities."
  check_etc_conflicts
  log "Homebrew activation policy: $("$TOOLS/jq" -c '{autoUpdate: .homebrew.autoUpdate, upgrade: .homebrew.upgrade, cleanup: .homebrew.cleanup}' "$WORK_DIR/config.json")"
}

cm() {
  "$TOOLS/chezmoi" --source "$REPO_DIR" --destination "$HOME" \
    --cache "$WORK_DIR/chezmoi-cache" --persistent-state "$WORK_DIR/chezmoi-state.boltdb" \
    --no-pager --color=false "$@"
}

check_etc_conflicts() {
  local row target path digest conflicts=0
  # Use nix-darwin's known hashes, not a hard-coded copy of macOS defaults.
  "$TOOLS/jq" -c '.etc[]' "$WORK_DIR/config.json" > "$WORK_DIR/etc.jsonl"
  while IFS= read -r row; do
    target="$(printf '%s' "$row" | "$TOOLS/jq" -r '.target')"
    path="/etc/$target"
    [[ -e "$path" || -L "$path" ]] || continue
    [[ "$(/usr/bin/readlink "$path" || true)" != "/etc/static/$target" ]] || continue
    if [[ -f "$path" && -r "$path" ]]; then
      digest="$(/usr/bin/shasum -a 256 "$path")"
      digest="${digest%% *}"
      if printf '%s' "$row" | "$TOOLS/jq" -e --arg hash "$digest" '.knownSha256Hashes | index($hash) != null' >/dev/null; then continue; fi
    fi
    printf >&2 'Conflicting file: %s\n' "$path"
    conflicts=1
  done < "$WORK_DIR/etc.jsonl"
  (( conflicts == 0 )) || die "Review conflicting /etc files and back them up manually before retrying. No files were moved."
}

validate_identity() {
  local path="$1" expected="$2" recipient
  recipient="$("$TOOLS/age-keygen" -y "$path" 2>/dev/null)" || die "Cannot read age identity: $path"
  [[ "$recipient" == "$expected" ]] || die "Unexpected age recipient for $path (not replaced)."
}

recover_identity() {
  local target="$1" backup="$2" expected="$3" label="$4" parent
  if [[ -e "$target" ]]; then
    validate_identity "$target" "$expected"
    return
  fi
  parent="${target%/*}"
  check_path "$target"
  /bin/mkdir -p "$parent"
  /bin/chmod 700 "$parent"
  IDENTITY_TEMP="$(/usr/bin/mktemp "$parent/.setup-age.XXXXXXXX")"
  log "Recovering $label identity. Enter its backup passphrase in the age prompt."
  "$TOOLS/age" --decrypt "$backup" > "$IDENTITY_TEMP"
  validate_identity "$IDENTITY_TEMP" "$expected"
  /bin/chmod 600 "$IDENTITY_TEMP"
  # Atomic create without replacing a file that appeared during the prompt.
  "$TOOLS/ln" -T "$IDENTITY_TEMP" "$target" || die "Identity destination appeared during recovery: $target"
  /bin/rm "$IDENTITY_TEMP"
  IDENTITY_TEMP=
}

validate_decryption() {
  STAGE=decryption
  local encrypted
  /usr/bin/git -C "$REPO_DIR" ls-files -z > "$WORK_DIR/tracked-files"
  while IFS= read -r -d '' encrypted; do
    case "${encrypted##*/}" in
      encrypted_*.age)
        "$TOOLS/age" --decrypt -i "$CHEZMOI_KEY" "$REPO_DIR/$encrypted" >/dev/null 2>&1 || die "chezmoi decryption failed: $encrypted" ;;
    esac
  done < "$WORK_DIR/tracked-files"
  "$TOOLS/jq" -r '.sopsFiles | unique[]' "$WORK_DIR/config.json" > "$WORK_DIR/sops-files"
  while IFS= read -r encrypted; do
    /usr/bin/env -u SOPS_AGE_KEY -u SOPS_AGE_KEY_CMD \
      XDG_CONFIG_HOME="$WORK_DIR/sops-config" GNUPGHOME="$WORK_DIR/sops-gnupg" \
      SOPS_AGE_KEY_FILE="$SOPS_KEY" "$TOOLS/sops" decrypt "$encrypted" >/dev/null 2>&1 ||
      die "SOPS decryption failed. Check the restored identity and secrets configuration."
  done < "$WORK_DIR/sops-files"
}

apply_configuration() {
  STAGE=build
  log "Building the locked system before applying home or macOS settings."
  "$NIX" flake check --no-build --no-update-lock-file "$FLAKE_DIR"
  "$NIX" build --no-update-lock-file --out-link "$WORK_DIR/system" "$FLAKE_DIR#darwinConfigurations.$HOST_KEY.system"
  SYSTEM_PATH="$(/usr/bin/readlink "$WORK_DIR/system")"
  [[ -x "$SYSTEM_PATH/sw/bin/darwin-rebuild" ]] || die "Built system has no darwin-rebuild."
  assert_clean_source

  STAGE=chezmoi
  check_path "$CHEZMOI_CONFIG"
  if [[ ! -e "$CHEZMOI_CONFIG" ]]; then
    /bin/mkdir -p "${CHEZMOI_CONFIG%/*}"
    IDENTITY_TEMP="$(/usr/bin/mktemp "${CHEZMOI_CONFIG%/*}/.setup-config.XXXXXXXX")"
    /usr/bin/install -m 600 "$WORK_DIR/chezmoi.toml" "$IDENTITY_TEMP"
    "$TOOLS/ln" -T "$IDENTITY_TEMP" "$CHEZMOI_CONFIG" || die "chezmoi config appeared during setup."
    /bin/rm "$IDENTITY_TEMP"
    IDENTITY_TEMP=
  fi
  log "chezmoi changes (paths only; no decrypted diff):"
  cm --config "$WORK_DIR/chezmoi-runtime.json" status
  # Keep chezmoi's conflict prompts. Do not use --force or --verbose.
  cm --config "$WORK_DIR/chezmoi-runtime.json" apply

  STAGE=activation
  assert_clean_source
  log "Applying nix-darwin. Homebrew may upgrade/remove apps according to the policy shown above."
  /usr/bin/sudo "$SYSTEM_PATH/sw/bin/darwin-rebuild" switch --no-update-lock-file --flake "$FLAKE_DIR#$HOST_KEY"
}

verify_result() {
  STAGE=verification
  local status current_shell desired_shell output mode actual attempt ready
  [[ "$(/usr/bin/readlink /run/current-system)" == "$SYSTEM_PATH" ]] || die "The active system differs from the built configuration."
  local profile="/etc/profiles/per-user/$USER_NAME"
  [[ -x "$profile/bin/chezmoi" && -x "$profile/bin/pre-commit" && -x "$profile/bin/zsh" ]] || die "Home Manager tools are missing."
  [[ "$(/opt/homebrew/bin/brew --prefix)" == /opt/homebrew ]] || die "Homebrew is unavailable at its expected prefix."
  status="$(cm --config "$WORK_DIR/chezmoi-runtime.json" status)"
  [[ -z "$status" ]] || die "chezmoi still reports differences. Run chezmoi status to inspect paths."

  # SOPS is a RunAtLoad LaunchAgent; bootstrap can return before it finishes.
  "$TOOLS/jq" -r '.sopsOutputs[] | [.path, .mode] | @tsv' "$WORK_DIR/config.json" > "$WORK_DIR/sops-outputs"
  ready=0
  for (( attempt=0; attempt<30; attempt++ )); do
    ready=1
    if ! /bin/launchctl print "gui/$USER_ID/org.nix-community.home.sops-nix" > "$WORK_DIR/sops-service" 2>/dev/null ||
      ! /usr/bin/grep -qE '^[[:space:]]*last exit code = 0$' "$WORK_DIR/sops-service"; then
      ready=0
    fi
    while IFS=$'\t' read -r output mode; do
      if [[ ! -f "$output" || ! -r "$output" || ! -O "$output" ]]; then ready=0; break; fi
      actual="$(/usr/bin/stat -Lf '%Lp' "$output")"
      if [[ "$actual" != "${mode#0}" ]]; then ready=0; break; fi
    done < "$WORK_DIR/sops-outputs"
    (( ready == 0 )) || break
    /bin/sleep 1
  done
  (( ready == 1 )) || die "SOPS outputs are missing or have unexpected permissions. Check ~/Library/Logs/SopsNix locally."

  STAGE=hooks
  "$profile/bin/pre-commit" install --config "$REPO_DIR/.pre-commit-config.yaml"
  current_shell="$(/usr/bin/dscl . -read "/Users/$USER_NAME" UserShell)"
  desired_shell="$("$TOOLS/jq" -r '.shell' "$WORK_DIR/config.json")"
  if [[ "${current_shell#UserShell: }" != "$desired_shell" ]]; then
    printf 'Login shell remains %s. To select the configured zsh after setup:\n  chsh -s %q\n' "${current_shell#UserShell: }" "$desired_shell"
  fi
  log "Setup completed. Open a new terminal."
  log "pass/passage data and YubiKey authentication/decryption tests are separate recovery steps."
}

main() {
  parse_args "$@"
  preflight
  [[ "$MODE" == apply ]] || return 0
  cd "$REPO_DIR"
  prepare_workdir
  validate_configuration
  STAGE=identities
  recover_identity "$CHEZMOI_KEY" "$CHEZMOI_BACKUP" "$CHEZMOI_RECIPIENT" chezmoi
  recover_identity "$SOPS_KEY" "$SOPS_BACKUP" "$SOPS_RECIPIENT" SOPS
  validate_decryption
  apply_configuration
  verify_result
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
