#!/bin/bash
# Restore a committed pass store using an existing PIV 9D key, after setup.sh.
# Bash 3.2 compatible. Never import software secrets or reconfigure a YubiKey.
set +x
set -Eeuo pipefail
umask 077

STAGE=arguments
MODE=check
MODE_SET=0
BACKUP_DIR=
BUNDLE=
PUBLIC_KEY=
RECOVERY_ARCHIVE=
PRIMARY_FPR=
ENCRYPTION_FPR=
KEYGRIP=
TEST_ENTRY=
ORIGIN=
WORK_DIR=
LOCK_DIR=
INSPECT_HOME=

log() { printf '==> %s\n' "$*"; }
die() { printf >&2 'ERROR [%s]: %s\n' "$STAGE" "$*"; exit 1; }

cleanup() {
  local result=$?
  trap - EXIT
  if [[ -n "$INSPECT_HOME" && -d "$INSPECT_HOME" ]]; then
    "$GPGCONF" --homedir "$INSPECT_HOME" --kill all >/dev/null 2>&1 || true
  fi
  [[ -z "$WORK_DIR" ]] || /bin/rm -rf -- "$WORK_DIR"
  [[ -z "$LOCK_DIR" ]] || /bin/rmdir "$LOCK_DIR"
  exit "$result"
}
trap cleanup EXIT
trap 'printf >&2 "ERROR [%s]: failed at line %s (exit %s).\n" "$STAGE" "$LINENO" "$?"' ERR
trap 'exit 130' INT
trap 'exit 143' TERM

usage() {
  cat <<'USAGE'
Usage: ./scripts/restore-pass.sh [--check | --apply]
  --primary-fingerprint HEX --encryption-fingerprint HEX --keygrip HEX
  --test-entry relative/entry
  [--backup-dir /absolute/directory] [--bundle /absolute/store.bundle]
  [--public-key /absolute/public.asc | --recovery-archive /absolute/recovery.tar.age]
  [--origin git@github.com:OWNER/REPO.git]

Default: --check; backup directory:
  ~/Library/Mobile Documents/com~apple~CloudDocs/share/pass
Default files: password-store-p256-git.bundle and public.asc.
Supply the independently verified primary/subkey fingerprints and PIV 9D keygrip.
The entry name excludes .gpg. Only local bundles are accepted; no network/push.

--check checks tools, paths, permissions and arguments only; no writes or GPG/card
operations. --apply validates cryptography and uses interactive PIN/Touch prompts.
--recovery-archive explicitly selects ONLY public.asc from an age-encrypted tar.
It is not software-secret recovery, and never falls back from a stale public.asc.
Existing ~/.password-store is always refused (also on reruns).
USAGE
}

parse_args() {
  while (( $# )); do
    case "$1" in
      --check|--apply)
        (( MODE_SET == 0 )) || die 'Choose one mode.'
        MODE="${1#--}"; MODE_SET=1; shift ;;
      --backup-dir|--bundle|--public-key|--recovery-archive|--primary-fingerprint|--encryption-fingerprint|--keygrip|--test-entry|--origin)
        [[ $# -ge 2 && -n "$2" ]] || die "Missing value for $1."
        case "$1" in
          --backup-dir) BACKUP_DIR="$2" ;;
          --bundle) BUNDLE="$2" ;;
          --public-key) PUBLIC_KEY="$2" ;;
          --recovery-archive) RECOVERY_ARCHIVE="$2" ;;
          --primary-fingerprint) PRIMARY_FPR="$2" ;;
          --encryption-fingerprint) ENCRYPTION_FPR="$2" ;;
          --keygrip) KEYGRIP="$2" ;;
          --test-entry) TEST_ENTRY="$2" ;;
          --origin) ORIGIN="$2" ;;
        esac
        shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown argument: $1" ;;
    esac
  done
  [[ -z "$PUBLIC_KEY" || -z "$RECOVERY_ARCHIVE" ]] || die 'Choose public key OR recovery archive.'
  BACKUP_DIR="${BACKUP_DIR:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/pass}"
  BUNDLE="${BUNDLE:-$BACKUP_DIR/password-store-p256-git.bundle}"
  if [[ -z "$RECOVERY_ARCHIVE" ]]; then PUBLIC_KEY="${PUBLIC_KEY:-$BACKUP_DIR/public.asc}"; fi
  PRIMARY_FPR="$(printf '%s' "$PRIMARY_FPR" | /usr/bin/tr '[:lower:]' '[:upper:]')"
  ENCRYPTION_FPR="$(printf '%s' "$ENCRYPTION_FPR" | /usr/bin/tr '[:lower:]' '[:upper:]')"
  KEYGRIP="$(printf '%s' "$KEYGRIP" | /usr/bin/tr '[:lower:]' '[:upper:]')"
  [[ "$PRIMARY_FPR" =~ ^[A-F0-9]{40}$ && "$ENCRYPTION_FPR" =~ ^[A-F0-9]{40}$ && "$KEYGRIP" =~ ^[A-F0-9]{40}$ ]] ||
    die 'Supply three verified 40-digit hexadecimal fingerprints/keygrip (without !).'
  [[ "$PRIMARY_FPR" != "$ENCRYPTION_FPR" ]] || die 'The encryption key must be a subkey.'
  [[ -n "$TEST_ENTRY" && "$TEST_ENTRY" != /* && "$TEST_ENTRY" != -* && "$TEST_ENTRY" != *.gpg && ! "$TEST_ENTRY" =~ [[:cntrl:]] ]] ||
    die 'Supply a relative test entry without .gpg or control characters.'
  case "/$TEST_ENTRY/" in */../*|*/./*|*//*|*/.git/*) die 'Unsafe test entry path.' ;; esac
  if [[ -n "$ORIGIN" ]]; then
    [[ "$ORIGIN" =~ ^git@github\.com:[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$ ||
       "$ORIGIN" =~ ^https://github\.com/[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$ ]] ||
      die 'Origin must be a GitHub SSH/HTTPS repository URL without credentials.'
  fi
}

check_owned_path() {
  local path="$1"
  while [[ "$path" == "$HOME" || "$path" == "$HOME/"* ]]; do
    [[ ! -L "$path" ]] || die 'Symlink in a sensitive destination path.'
    if [[ -e "$path" ]]; then [[ -O "$path" ]] || die 'Destination is not owned by this user.'; fi
    [[ "$path" != "$HOME" ]] || break
    path="${path%/*}"
  done
}

require_new_store() {
  check_owned_path "$TARGET"
  [[ ! -e "$TARGET" && ! -L "$TARGET" ]] || die 'The password-store destination already exists; nothing will be overwritten.'
}

check_input() {
  local path="$1"
  [[ "$path" == /* && ! "$path" =~ [[:cntrl:]] && ! -L "$path" && -f "$path" && -r "$path" && -s "$path" ]] ||
    die 'Backup must be a downloaded, nonempty, readable regular file at an absolute path (not a symlink).'
}

preflight() {
  STAGE=preflight
  [[ "$(/usr/bin/uname -s)" == Darwin && "$(/usr/bin/uname -m)" == arm64 && "$EUID" != 0 ]] ||
    die 'Run natively on Apple Silicon as the normal user, without sudo.'
  [[ "$HOME" == /* && -d "$HOME" ]] || die 'Invalid HOME.'
  TARGET="$HOME/.password-store"
  GPG_HOME="$HOME/.gnupg"
  require_new_store
  check_owned_path "$GPG_HOME/private-keys-v1.d"
  [[ -z "${GNUPGHOME:-}" || "$GNUPGHOME" == "$GPG_HOME" ]] || die 'Custom GNUPGHOME is not supported.'
  [[ -z "${PASSWORD_STORE_DIR:-}" || "$PASSWORD_STORE_DIR" == "$TARGET" ]] || die 'Custom PASSWORD_STORE_DIR is not supported.'
  [[ -z "${PASSWORD_STORE_KEY:-}${PASSWORD_STORE_GPG_OPTS:-}${PASSWORD_STORE_SIGNING_KEY:-}${PASSWORD_STORE_EXTENSIONS_DIR:-}" &&
     "${PASSWORD_STORE_ENABLE_EXTENSIONS:-false}" == false ]] || die 'Remove custom pass key/options/extension overrides before restoring.'
  [[ -d "$GPG_HOME" && "$(/usr/bin/stat -f '%Lp' "$GPG_HOME")" == 700 ]] || die 'Run setup.sh first; ~/.gnupg must exist with mode 700.'
  /usr/bin/grep -Eq '^[[:space:]]*application-priority[[:space:]]+piv[[:space:]]*$' "$GPG_HOME/scdaemon.conf" ||
    die 'The managed scdaemon configuration must prefer PIV.'
  check_input "$BUNDLE"
  if [[ -n "$RECOVERY_ARCHIVE" ]]; then check_input "$RECOVERY_ARCHIVE"; else check_input "$PUBLIC_KEY"; fi
  local profile tool
  profile="/etc/profiles/per-user/$(/usr/bin/id -un)/bin"
  export PATH="$profile:/usr/bin:/bin:/usr/sbin:/sbin"
  for tool in gpg gpgconf gpg-connect-agent pass git age ykman pinentry-mac; do
    [[ -x "$profile/$tool" ]] || die "Missing $tool in the Home Manager profile; run setup.sh first."
  done
  GPG="$profile/gpg"; GPGCONF="$profile/gpgconf"
  AGENT="$profile/gpg-connect-agent"; PASS="$profile/pass"; GIT="$profile/git"
  AGE="$profile/age"; YKMAN="$profile/ykman"
  if [[ "$MODE" == apply ]]; then
    [[ -t 0 && -t 1 ]] || die 'Use an interactive terminal; do not log the session.'
    GPG_TTY="$(/usr/bin/tty)"; export GPG_TTY
  fi
}

# Backup repositories must not inherit executable hooks, filters or URL rewrites.
safe_git() {
  /usr/bin/env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_COMMON_DIR \
    -u GIT_OBJECT_DIRECTORY -u GIT_ALTERNATE_OBJECT_DIRECTORIES \
    -u GIT_CONFIG_PARAMETERS -u GIT_CONFIG_COUNT -u GIT_TEMPLATE_DIR \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_GLOBAL=/dev/null \
    GIT_TERMINAL_PROMPT=0 "$GIT" -c core.hooksPath=/dev/null -c init.templateDir= \
    -c protocol.allow=never -c protocol.file.allow=always "$@"
}

prepare_workdir() {
  STAGE=preparation
  local lock="$HOME/.restore-pass.lock"
  /bin/mkdir "$lock" 2>/dev/null || die 'Another restore is running, or ~/.restore-pass.lock remains after interruption.'
  LOCK_DIR="$lock"
  WORK_DIR="$(/usr/bin/mktemp -d "$HOME/.restore-pass.XXXXXXXX")"
  INSPECT_HOME="$WORK_DIR/gnupg"
  /bin/mkdir -m 700 "$INSPECT_HOME"
  # No card access from the disposable public-key inspection agent.
  printf 'disable-scdaemon\n' > "$INSPECT_HOME/gpg-agent.conf"
  STORE="$WORK_DIR/store"
}

validate_store() {
  STAGE=bundle
  # An empty repository verifies that this bundle has no prerequisite commits.
  safe_git init --bare -q "$WORK_DIR/bundle-check" 2>"$WORK_DIR/errors"
  safe_git -C "$WORK_DIR/bundle-check" bundle verify "$BUNDLE" >"$WORK_DIR/bundle-info" 2>"$WORK_DIR/errors" || die 'Invalid or incremental bundle; a self-contained backup is required.'
  safe_git clone --no-checkout --origin origin "$BUNDLE" "$STORE" >"$WORK_DIR/clone-info" 2>"$WORK_DIR/errors" || die 'Bundle clone failed.'
  safe_git -C "$STORE" fsck --full >"$WORK_DIR/fsck-info" 2>"$WORK_DIR/errors" || die 'Git object integrity check failed.'
  safe_git -C "$STORE" ls-tree -rz HEAD > "$WORK_DIR/tree"
  local record mode path
  while IFS= read -r -d '' record; do
    mode="${record%% *}"; path="${record#*$'\t'}"
    [[ "$mode" == 100644 || "$mode" == 100755 ]] || die 'Store contains a symlink or submodule; review manually.'
    [[ ! "$path" =~ [[:cntrl:]] ]] || die 'Store contains control characters in a path.'
  done < "$WORK_DIR/tree"
  safe_git -C "$STORE" checkout --force >"$WORK_DIR/checkout-info" 2>"$WORK_DIR/errors"
  [[ -f "$STORE/.gpg-id" && -f "$STORE/$TEST_ENTRY.gpg" ]] || die 'Missing .gpg-id or selected test entry.'
  /usr/bin/find "$STORE" -name .gpg-id -type f -print0 > "$WORK_DIR/recipients"
  while IFS= read -r -d '' path; do
    printf '%s!\n' "$ENCRYPTION_FPR" | /usr/bin/cmp -s - "$path" || die 'A .gpg-id differs from the expected P-256 subkey; it was not changed.'
  done < "$WORK_DIR/recipients"
  if [[ -n "$ORIGIN" ]]; then
    safe_git -C "$STORE" remote set-url origin "$ORIGIN"
  else
    safe_git -C "$STORE" remote remove origin
  fi
  log "Bundle commit: $(safe_git -C "$STORE" rev-parse HEAD)"
}

inspect_gpg() { "$GPG" --no-options --homedir "$INSPECT_HOME" --batch "$@"; }
user_gpg() { "$GPG" --no-options --homedir "$GPG_HOME" "$@"; }

validate_key_listing() {
  /usr/bin/awk -F: -v primary="$PRIMARY_FPR" -v encryption="$ENCRYPTION_FPR" -v grip="$KEYGRIP" -v now="$(/bin/date +%s)" '
    $1 == "sec" || $1 == "ssb" { bad = 1 }
    $1 == "pub" || $1 == "sub" {
      kind = $1; valid = ($2 !~ /[reidn]/ && $12 !~ /D/ && (!$7 || $7 > now))
      encrypt = ($4 == 18 && $12 ~ /e/ && $17 == "nistp256")
      selected = 0
      if (kind == "pub") { pubs++; if (!valid) bad = 1 }
    }
    $1 == "fpr" && kind == "pub" { if ($10 != primary) bad = 1 }
    $1 == "fpr" && kind == "sub" && $10 == encryption {
      found++; selected = 1; if (!valid || !encrypt) bad = 1
    }
    $1 == "grp" && selected { if ($10 == grip) grips++; else bad = 1 }
    END { exit (bad || pubs != 1 || found != 1 || grips != 1) }
  ' "$1" || die 'Public key mismatch: require the verified primary and usable P-256 subkey/keygrip. An old public.asc may lack the new subkey; explicitly use --recovery-archive if appropriate.'
}

validate_public_key() {
  STAGE=public-key
  if [[ -n "$RECOVERY_ARCHIVE" ]]; then
    log 'Extracting ONLY public.asc. Enter the archive age passphrase at the age prompt.'
    # Never materialize the decrypted archive, secret.asc, or portable private keys.
    ( ulimit -f 2048
      "$AGE" --decrypt "$RECOVERY_ARCHIVE" |
        /usr/bin/tar -xOf - ./public.asc > "$WORK_DIR/public.input"
    ) || die 'Archive public-key extraction failed; no keys were imported.'
  else
    /bin/cp "$PUBLIC_KEY" "$WORK_DIR/public.input"
  fi
  inspect_gpg --with-colons --with-fingerprint --with-subkey-fingerprint --with-keygrip \
    --import-options show-only --import "$WORK_DIR/public.input" > "$WORK_DIR/key-list" 2> "$WORK_DIR/errors" || die 'Cannot parse the supplied public key.'
  validate_key_listing "$WORK_DIR/key-list"
  inspect_gpg --import "$WORK_DIR/public.input" > /dev/null 2> "$WORK_DIR/errors" || die 'Public-key self-signature validation/import failed.'
  inspect_gpg --with-colons --with-subkey-fingerprint --with-keygrip --list-keys > "$WORK_DIR/key-list" 2> "$WORK_DIR/errors"
  validate_key_listing "$WORK_DIR/key-list"
  # Only a canonical public export can ever enter the real GNUPGHOME.
  inspect_gpg --export "$PRIMARY_FPR" > "$WORK_DIR/public.gpg" 2> "$WORK_DIR/errors"
  [[ -s "$WORK_DIR/public.gpg" ]] || die 'Empty public-key export.'
}

confirm_restore() {
  STAGE=confirmation
  log "Verified primary: $PRIMARY_FPR / encryption subkey: $ENCRYPTION_FPR"
  log "PIV 9D keygrip: $KEYGRIP"
  log 'This will import this PUBLIC key, trust this own primary key, learn the existing card, and create ~/.password-store.'
  log 'No secret key import, YubiKey reconfiguration, pass init, key deletion, or push.'
  local answer
  read -r -p 'If these are YOUR independently verified keys and the intended backup, type restore: ' answer
  [[ "$answer" == restore ]] || die 'Cancelled before changing your GPG state or store.'
}

validate_card_info() {
  /usr/bin/awk -v grip="$KEYGRIP" '
    $1 == "ERR" { bad = 1 }
    $1 == "S" && $2 == "APPTYPE" && $3 == "PIV" { piv++ }
    $1 == "S" && $2 == "KEYPAIRINFO" && $3 == grip && $4 == "PIV.9D" { key++ }
    END { exit (bad || piv != 1 || key != 1) }
  ' "$1" || die 'The connected card does not report the expected PIV 9D key.'
}

validate_shadow_info() {
  /usr/bin/awk -v grip="$KEYGRIP" '
    $1 == "ERR" { bad = 1 }
    $1 == "S" && $2 == "KEYINFO" && $3 == grip {
      found++; if ($4 != "T" || $6 != "PIV.9D") bad = 1
    }
    END { exit (bad || found != 1) }
  ' "$1" || die 'Expected a PIV 9D shadow key, not a software private key. Nothing was deleted.'
}

restore_gpg() {
  STAGE=gpg
  require_new_store
  "$YKMAN" list --serials > "$WORK_DIR/cards" 2> "$WORK_DIR/errors" || die 'Cannot enumerate YubiKeys.'
  /usr/bin/awk 'NF { count++; if ($0 !~ /^[0-9]+$/) bad = 1 } END { exit (bad || count != 1) }' "$WORK_DIR/cards" || die 'Connect exactly one existing YubiKey.'
  # Restart only the card daemon; do not reset the card or kill the SSH agent.
  "$GPGCONF" --homedir "$GPG_HOME" --kill scdaemon
  "$AGENT" --homedir "$GPG_HOME" 'SCD LEARN --force' /bye > "$WORK_DIR/card-info" 2> "$WORK_DIR/errors" || die 'Cannot read the PIV card.'
  validate_card_info "$WORK_DIR/card-info"
  # READKEY creates only the requested shadow if absent, never replacing an
  # existing private key. Unlike checkkeys, this does not learn other slots.
  "$AGENT" --homedir "$GPG_HOME" 'READKEY --card --no-data PIV.9D' /bye > "$WORK_DIR/readkey-info" 2> "$WORK_DIR/errors" || die 'Cannot learn the PIV 9D shadow key.'
  /usr/bin/grep -q '^ERR ' "$WORK_DIR/readkey-info" && die 'PIV 9D shadow-key creation failed.'
  "$AGENT" --homedir "$GPG_HOME" "KEYINFO $KEYGRIP" /bye > "$WORK_DIR/shadow-info" 2> "$WORK_DIR/errors" || die 'Cannot inspect the shadow key.'
  validate_shadow_info "$WORK_DIR/shadow-info"
  user_gpg --batch --import "$WORK_DIR/public.gpg" > /dev/null 2> "$WORK_DIR/errors" || die 'Public-key import failed.'
  user_gpg --batch --with-colons --with-subkey-fingerprint --with-keygrip --list-keys "$PRIMARY_FPR" > "$WORK_DIR/key-list" 2> "$WORK_DIR/errors"
  validate_key_listing "$WORK_DIR/key-list"
  user_gpg --batch --export-ownertrust > "$WORK_DIR/trust" 2> "$WORK_DIR/errors"
  local trust
  trust="$(/usr/bin/awk -F: -v key="$PRIMARY_FPR" '$1 == key { print $2 }' "$WORK_DIR/trust")"
  case "$trust" in
    6) ;;
    ''|1|2)
      printf '%s:6:\n' "$PRIMARY_FPR" |
        user_gpg --batch --import-ownertrust > /dev/null 2> "$WORK_DIR/errors" ;;
    *) die 'Existing ownertrust conflicts with ultimate trust for this own key; review manually.' ;;
  esac
}

validate_decryption_status() {
  /usr/bin/awk -v key="$ENCRYPTION_FPR" -v primary="$PRIMARY_FPR" '
    $1 == "[GNUPG:]" && $2 == "DECRYPTION_KEY" { if ($3 == key && $4 == primary) found++; else bad = 1 }
    $1 == "[GNUPG:]" && $2 == "DECRYPTION_OKAY" { okay++ }
    $1 == "[GNUPG:]" && $2 ~ /^(DECRYPTION_FAILED|BADMDC|ERRMDC|ERROR|FAILURE)$/ { bad = 1 }
    END { exit (bad || found != 1 || okay != 1) }
  ' "$1" || die 'Decryption did not confirm the expected P-256 key.'
}

verify_store() {
  STAGE=decryption
  log 'Verifying the selected entry. Use the existing PIV PIN/Touch when requested; do not guess PINs.'
  user_gpg --status-fd 3 --decrypt "$STORE/$TEST_ENTRY.gpg" 3> "$WORK_DIR/decryption-status" > /dev/null 2> "$WORK_DIR/errors" || die 'Entry decryption failed; no PIN retries were attempted by this script.'
  validate_decryption_status "$WORK_DIR/decryption-status"
  /usr/bin/env GNUPGHOME="$GPG_HOME" PASSWORD_STORE_DIR="$STORE" \
    PASSWORD_STORE_ENABLE_EXTENSIONS=false PASSWORD_STORE_GPG_OPTS=--no-options \
    "$PASS" show "$TEST_ENTRY" > /dev/null 2> "$WORK_DIR/errors" || die 'pass show failed; the store was not installed.'
  STAGE=roundtrip
  printf 'pass restore test\n' > "$WORK_DIR/test.txt"
  user_gpg --batch --trust-model pgp --encrypt --recipient "$ENCRYPTION_FPR!" \
    --output "$WORK_DIR/test.gpg" "$WORK_DIR/test.txt" 2> "$WORK_DIR/errors" || die 'Encryption failed; check public key and ownertrust.'
  user_gpg --status-fd 3 --decrypt "$WORK_DIR/test.gpg" 3> "$WORK_DIR/decryption-status" 2> "$WORK_DIR/errors" |
    /usr/bin/cmp -s - "$WORK_DIR/test.txt" || die 'Test roundtrip failed.'
  validate_decryption_status "$WORK_DIR/decryption-status"
}

install_store() {
  STAGE=installation
  require_new_store
  # mkdir exclusively claims a previously nonexistent destination, including in
  # the presence of a race. Never mv into an existing directory or follow a link.
  /bin/mkdir -m 700 "$TARGET" || die 'Destination appeared during restoration; not overwritten.'
  /bin/cp -R "$STORE/." "$TARGET/" || die 'Copy failed. The newly created store may be partial; inspect manually. It was not removed.'
  safe_git -C "$TARGET" fsck --full > "$WORK_DIR/fsck-info" 2> "$WORK_DIR/errors" || die 'Installed Git integrity check failed; inspect manually.'
  [[ -z "$(safe_git -C "$TARGET" status --porcelain --untracked-files=all)" ]] || die 'Installed store differs from its commit; inspect manually.'
  log 'pass restoration completed. No existing store, password entry, or YubiKey configuration was overwritten.'
  [[ -n "$ORIGIN" ]] || log 'No origin configured. Set the verified GitHub URL before syncing.'
  log 'Test the other YubiKey separately. Git SSH authentication/signing and disaster recovery are separate checks.'
}

main() {
  parse_args "$@"
  preflight
  if [[ "$MODE" == check ]]; then
    log 'Local checks passed. Public-key contents, bundle, card, and decryption are checked during --apply.'
    return
  fi
  prepare_workdir
  validate_store
  validate_public_key
  confirm_restore
  restore_gpg
  verify_store
  install_store
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
