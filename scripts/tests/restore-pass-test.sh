#!/bin/bash
# Real disposable GPG keys/Git bundles; simulated cards, never real identities or
# YubiKeys. This tests recovery safeguards, NOT physical PIV/GUI integration.
# shellcheck disable=SC2016
set -Eeuo pipefail
umask 077
REPO="$(cd "$(dirname "$0")/../.." && pwd -P)"
# Keep Unix-domain socket paths below macOS limits, even for long test names.
TEST_ROOT="$(/usr/bin/mktemp -d /private/tmp/rp.XXXXXXXX)"
GPG="$(command -v gpg)"
GPGCONF="$(command -v gpgconf)"
GIT="$(command -v git)"
PASS="$(command -v pass)"
REAL_AGENT="$(command -v gpg-connect-agent)"
AGE="$(command -v age)"
FIXTURE_HOME="$TEST_ROOT/keys"
passed=0

cleanup_tests() {
  local dir
  while IFS= read -r -d '' dir; do
    "$GPGCONF" --homedir "${dir%/gpg-agent.conf}" --kill all >/dev/null 2>&1 || true
  done < <(/usr/bin/find "$TEST_ROOT" -name gpg-agent.conf -print0)
  /bin/rm -rf -- "$TEST_ROOT"
}
trap cleanup_tests EXIT
fail() { printf >&2 'FAIL: %s\n' "$*"; exit 1; }

mkdir -m 700 "$FIXTURE_HOME"
printf 'disable-scdaemon\n' > "$FIXTURE_HOME/gpg-agent.conf"
fixture_gpg() { "$GPG" --no-options --homedir "$FIXTURE_HOME" --batch --pinentry-mode loopback --passphrase '' "$@"; }
fixture_gpg --quick-generate-key 'Restore Test <restore@example.invalid>' nistp256 cert 0 >/dev/null 2> "$TEST_ROOT/errors"
PRIMARY_FPR="$(fixture_gpg --with-colons --list-keys 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }')"
fixture_gpg --armor --export "$PRIMARY_FPR" > "$TEST_ROOT/old-public.asc"
fixture_gpg --quick-add-key "$PRIMARY_FPR" nistp256 encr 0 >/dev/null 2> "$TEST_ROOT/errors"
fixture_gpg --with-colons --with-keygrip --list-keys > "$TEST_ROOT/key-list" 2>/dev/null
ENCRYPTION_FPR="$(awk -F: '$1 == "sub" { subkey = 1 } subkey && $1 == "fpr" { print $10; exit }' "$TEST_ROOT/key-list")"
KEYGRIP="$(awk -F: '$1 == "sub" { subkey = 1 } subkey && $1 == "grp" { print $10; exit }' "$TEST_ROOT/key-list")"
fixture_gpg --armor --export "$PRIMARY_FPR" > "$TEST_ROOT/public.asc"
fixture_gpg --armor --export-secret-keys "$PRIMARY_FPR" > "$TEST_ROOT/secret.asc"
mkdir "$TEST_ROOT/source"
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "$GIT" init -q "$TEST_ROOT/source"
printf '%s!\n' "$ENCRYPTION_FPR" > "$TEST_ROOT/source/.gpg-id"
printf 'synthetic-pass-secret\n' | fixture_gpg --encrypt -r "$ENCRYPTION_FPR!" > "$TEST_ROOT/source/test.gpg"
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "$GIT" -C "$TEST_ROOT/source" add .
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "$GIT" -C "$TEST_ROOT/source" \
  -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false commit -qm fixture
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "$GIT" -C "$TEST_ROOT/source" bundle create "$TEST_ROOT/store.bundle" --all

# The actual age decryption is exercised with a generated identity, not a PIN or
# backup passphrase. The wrapper below only substitutes this test identity.
age-keygen -o "$TEST_ROOT/age-key" 2>/dev/null
AGE_RECIPIENT="$(age-keygen -y "$TEST_ROOT/age-key")"
mkdir "$TEST_ROOT/archive"
cp "$TEST_ROOT/public.asc" "$TEST_ROOT/archive/public.asc"
cp "$TEST_ROOT/secret.asc" "$TEST_ROOT/archive/secret.asc"
tar -c -C "$TEST_ROOT/archive" ./public.asc ./secret.asc |
  "$AGE" -r "$AGE_RECIPIENT" > "$TEST_ROOT/recovery.tar.age"

export REPO TEST_ROOT GPG GPGCONF GIT PASS REAL_AGENT AGE PRIMARY_FPR ENCRYPTION_FPR KEYGRIP

run_case() {
  local name="$1" body="$2" expected="${3:-0}" expected_error="${4:-}" result=0
  local case_home="$TEST_ROOT/c$passed/h"
  LAST_CASE_HOME="$case_home"
  mkdir -p "$case_home/.gnupg" "$TEST_ROOT/$name"
  chmod 700 "$case_home/.gnupg"
  printf 'disable-scdaemon\n' > "$case_home/.gnupg/gpg-agent.conf"
  printf 'application-priority piv\n' > "$case_home/.gnupg/scdaemon.conf"
  /usr/bin/env HOME="$case_home" GNUPGHOME="$case_home/.gnupg" \
    XDG_CONFIG_HOME="$case_home/.config" XDG_CACHE_HOME="$case_home/.cache" \
    XDG_DATA_HOME="$case_home/.local/share" XDG_STATE_HOME="$case_home/.local/state" \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    /bin/bash -c '
      # Save the synthetic identifiers before sourcing resets production options.
      fixture_primary="$PRIMARY_FPR"; fixture_encryption="$ENCRYPTION_FPR"; fixture_grip="$KEYGRIP"
      source "$REPO/scripts/restore-pass.sh"
      # Retain synthetic-only diagnostics outside the production cleanup area.
      die() {
        if [[ -f "$WORK_DIR/errors" ]]; then cp "$WORK_DIR/errors" "$HOME/test-diagnostic"; fi
        printf >&2 "ERROR [%s]: %s\n" "$STAGE" "$*"
        exit 1
      }
      PRIMARY_FPR="$fixture_primary"; ENCRYPTION_FPR="$fixture_encryption"; KEYGRIP="$fixture_grip"
      TARGET="$HOME/.password-store"; GPG_HOME="$HOME/.gnupg"
      BUNDLE="$TEST_ROOT/store.bundle"; PUBLIC_KEY="$TEST_ROOT/public.asc"; TEST_ENTRY=test
      prepare_workdir
      eval "$1"
    ' test "$body" > "$TEST_ROOT/$name/output" 2>&1 || result=$?
  [[ "$result" == "$expected" ]] || {
    sed -n '/^ERROR /p' "$TEST_ROOT/$name/output" >&2
    if [[ -f "$case_home/test-diagnostic" ]]; then sed -n '1,15p' "$case_home/test-diagnostic" >&2; fi
    fail "$name exited $result, expected $expected"
  }
  if [[ -n "$expected_error" ]]; then
    grep -Fq "$expected_error" "$TEST_ROOT/$name/output" || fail "$name failed for an unexpected reason"
  fi
  [[ -z "$(find "$case_home" -maxdepth 1 -name '.restore-pass*' -print)" ]] || fail "$name left workspace/lock"
  ! grep -qE 'synthetic-pass-secret|BEGIN PGP PRIVATE KEY|AGE-SECRET-KEY-' "$TEST_ROOT/$name/output" || fail "$name leaked fixture secrets"
  printf 'PASS: %s\n' "$name"
  passed=$((passed + 1))
}

mock_card_tools() {
  # Called indirectly via the executable variables in the sourced production file.
  # shellcheck disable=SC2329
  YKMAN() { printf '123456\n'; }
  # shellcheck disable=SC2329
  AGENT() {
    case "$3" in
      # Match the actual scdaemon response, including lowercase APPTYPE.
      'SCD LEARN --force') printf 'S APPTYPE piv\nS KEYPAIRINFO %s PIV.9D e\nOK\n' "$KEYGRIP" ;;
      'READKEY --card --no-data PIV.9D') printf 'OK\n' ;;
      KEYINFO*) printf 'S KEYINFO %s %s card-serial PIV.9D - - -\nOK\n' "$KEYGRIP" "${MOCK_KEY_TYPE:-T}" ;;
      *) return 1 ;;
    esac
  }
  export YKMAN=YKMAN AGENT=AGENT
}
export -f mock_card_tools

run_case valid_public 'validate_public_key'
run_case stale_public 'PUBLIC_KEY="$TEST_ROOT/old-public.asc"; validate_public_key' 1 'Public key mismatch'
run_case secret_input 'PUBLIC_KEY="$TEST_ROOT/secret.asc"; validate_public_key' 1 'Public key mismatch'
run_case wrong_primary 'PRIMARY_FPR=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA; validate_public_key' 1
run_case wrong_grip 'KEYGRIP=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA; validate_public_key' 1
run_case corrupt_public 'PUBLIC_KEY="$TEST_ROOT/source/test.gpg"; validate_public_key' 1
run_case public_archive '
  real_age="$AGE"
  decrypt_fixture() { "$real_age" --decrypt -i "$TEST_ROOT/age-key" "$2"; }
  AGE=decrypt_fixture; RECOVERY_ARCHIVE="$TEST_ROOT/recovery.tar.age"
  validate_public_key
  [[ ! -e "$WORK_DIR/secret.asc" && ! -e "$GPG_HOME/private-keys-v1.d" ]]
  ! grep -q "PRIVATE KEY" "$WORK_DIR/public.input"
'
run_case archive_failure '
  bad_age() { printf "partial-secret"; return 1; }
  AGE=bad_age; RECOVERY_ARCHIVE="$TEST_ROOT/recovery.tar.age"; validate_public_key
' 1
run_case valid_bundle 'validate_store; [[ -z "$(safe_git -C "$STORE" remote)" ]]'
run_case origin_configured 'ORIGIN=git@github.com:example/password-store.git; validate_store; [[ "$(safe_git -C "$STORE" remote get-url origin)" == "$ORIGIN" ]]'
run_case wrong_recipient 'ENCRYPTION_FPR=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA; validate_store' 1 '.gpg-id differs'
run_case missing_entry 'TEST_ENTRY=missing; validate_store' 1
run_case corrupt_bundle 'BUNDLE="$TEST_ROOT/public.asc"; validate_store' 1
run_case symlink_tree '
  safe_git clone -q "$BUNDLE" "$WORK_DIR/bad"
  ln -s /tmp "$WORK_DIR/bad/link"
  safe_git -C "$WORK_DIR/bad" add link
  safe_git -C "$WORK_DIR/bad" -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false commit -qm link
  safe_git -C "$WORK_DIR/bad" bundle create "$WORK_DIR/bad.bundle" --all
  BUNDLE="$WORK_DIR/bad.bundle"; validate_store
' 1
run_case incremental_bundle '
  safe_git clone -q "$BUNDLE" "$WORK_DIR/bad"
  printf second > "$WORK_DIR/bad/second"
  safe_git -C "$WORK_DIR/bad" add second
  safe_git -C "$WORK_DIR/bad" -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false commit -qm second
  safe_git -C "$WORK_DIR/bad" bundle create "$WORK_DIR/bad.bundle" HEAD~1..HEAD
  BUNDLE="$WORK_DIR/bad.bundle"; validate_store
' 1
run_case existing_store 'mkdir "$TARGET"; printf original > "$TARGET/sentinel"; require_new_store' 1 'destination already exists'
[[ "$(< "$LAST_CASE_HOME/.password-store/sentinel")" == original ]] || fail 'existing store changed'
run_case dangling_destination 'ln -s "$HOME/absent" "$TARGET"; require_new_store' 1
run_case cancelled 'validate_public_key; confirm_restore <<< no' 1
run_case card_lowercase_piv '
  printf "S APPTYPE piv\nS KEYPAIRINFO %s PIV.9D e\nOK\n" "$KEYGRIP" > "$WORK_DIR/card"
  validate_card_info "$WORK_DIR/card"
'
run_case card_uppercase_piv '
  printf "S APPTYPE PIV\nS KEYPAIRINFO %s PIV.9D e\nOK\n" "$KEYGRIP" > "$WORK_DIR/card"
  validate_card_info "$WORK_DIR/card"
'
run_case card_wrong_grip '
  printf "S APPTYPE piv\nS KEYPAIRINFO AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA PIV.9D e\nOK\n" > "$WORK_DIR/card"
  validate_card_info "$WORK_DIR/card"
' 1 'expected PIV 9D key'
run_case card_missing_apptype '
  printf "S KEYPAIRINFO %s PIV.9D e\nOK\n" "$KEYGRIP" > "$WORK_DIR/card"
  validate_card_info "$WORK_DIR/card"
' 1 'expected PIV 9D key'
run_case card_duplicate_apptype '
  printf "S APPTYPE piv\nS APPTYPE PIV\nS KEYPAIRINFO %s PIV.9D e\nOK\n" "$KEYGRIP" > "$WORK_DIR/card"
  validate_card_info "$WORK_DIR/card"
' 1 'expected PIV 9D key'
run_case card_duplicate_key '
  printf "S APPTYPE piv\nS KEYPAIRINFO %s PIV.9D e\nS KEYPAIRINFO %s PIV.9D e\nOK\n" "$KEYGRIP" "$KEYGRIP" > "$WORK_DIR/card"
  validate_card_info "$WORK_DIR/card"
' 1 'expected PIV 9D key'
run_case card_mismatch '
  printf "S APPTYPE openpgp\nS KEYPAIRINFO %s PIV.9D e\nOK\n" "$KEYGRIP" > "$WORK_DIR/card"
  validate_card_info "$WORK_DIR/card"
' 1 'expected PIV 9D key'
run_case card_assuan_error '
  printf "S APPTYPE piv\nS KEYPAIRINFO %s PIV.9D e\nERR 1\n" "$KEYGRIP" > "$WORK_DIR/card"
  validate_card_info "$WORK_DIR/card"
' 1 'expected PIV 9D key'
run_case software_key_rejected '
  validate_public_key
  mock_card_tools; MOCK_KEY_TYPE=D
  restore_gpg
' 1 'not a software private key'
run_case gpg_public_only '
  validate_public_key; mock_card_tools; restore_gpg
  user_gpg --batch --export-ownertrust > "$WORK_DIR/result"
  grep -q "$PRIMARY_FPR:6:" "$WORK_DIR/result"
  [[ ! -s "$GPG_HOME/private-keys-v1.d/$KEYGRIP.key" ]]
'
run_case conflicting_trust '
  validate_public_key
  user_gpg --batch --import "$WORK_DIR/public.gpg" >/dev/null 2>&1
  printf "%s:3:\n" "$PRIMARY_FPR" | user_gpg --batch --import-ownertrust >/dev/null 2>&1
  mock_card_tools; restore_gpg
' 1 'Existing ownertrust conflicts'
run_case real_software_keyinfo '
  user_gpg --batch --pinentry-mode loopback --passphrase "" --import "$TEST_ROOT/secret.asc" >/dev/null 2>&1
  "$REAL_AGENT" --homedir "$GPG_HOME" "KEYINFO $KEYGRIP" /bye > "$WORK_DIR/info"
  validate_shadow_info "$WORK_DIR/info"
' 1 'not a software private key'
run_case decryption_status_failure 'printf "[GNUPG:] DECRYPTION_OKAY\n" > "$WORK_DIR/status"; validate_decryption_status "$WORK_DIR/status"' 1
run_case complete_simulated_restore '
  validate_store; validate_public_key
  # Software fixture simulates the cryptographic result of the mocked PIV card.
  user_gpg --batch --pinentry-mode loopback --passphrase "" --import "$TEST_ROOT/secret.asc" >/dev/null 2>&1
  mock_card_tools; confirm_restore <<< restore; restore_gpg; verify_store; install_store
  [[ -f "$TARGET/test.gpg" && -d "$TARGET/.git" ]]
  [[ "$(/usr/bin/stat -f %Lp "$TARGET")" == 700 ]]
  cmp -s "$TEST_ROOT/source/test.gpg" "$TARGET/test.gpg"
  [[ -z "$(safe_git -C "$TARGET" status --porcelain)" ]]
'
run_case failed_decrypt_not_installed '
  validate_store; validate_public_key; mock_card_tools; restore_gpg
  verify_store
' 1 'Entry decryption failed'
[[ ! -e "$LAST_CASE_HOME/.password-store" ]] || fail 'failed decryption installed a store'
run_case installation_collision 'validate_store; mkdir "$TARGET"; printf original > "$TARGET/sentinel"; install_store' 1
[[ "$(< "$LAST_CASE_HOME/.password-store/sentinel")" == original ]] || fail 'collision changed store'
run_case interrupted 'kill -TERM "$$"' 143

run_case path_traversal 'parse_args --test-entry ../elsewhere' 1 'Unsafe test entry'
run_case conflicting_modes 'parse_args --apply --check' 1 'Choose one mode'
run_case secret_source_ambiguity 'parse_args --recovery-archive "$TEST_ROOT/recovery.tar.age"' 1 'Choose public key OR'
run_case unsafe_origin 'parse_args --origin "ext::command"' 1 'Origin must be'
run_case unknown_option 'parse_args --force' 1 'Unknown argument'
run_case expired_key '
  validate_public_key
  awk -F: '\''BEGIN { OFS = ":" } $1 == "sub" { $7 = 1 } { print }'\'' "$WORK_DIR/key-list" > "$WORK_DIR/expired"
  validate_key_listing "$WORK_DIR/expired"
' 1 'Public key mismatch'
run_case incorrect_curve '
  validate_public_key
  awk -F: '\''BEGIN { OFS = ":" } $1 == "sub" { $17 = "nistp384" } { print }'\'' "$WORK_DIR/key-list" > "$WORK_DIR/curve"
  validate_key_listing "$WORK_DIR/curve"
' 1 'Public key mismatch'
run_case mixed_secret_input '
  cat "$TEST_ROOT/public.asc" "$TEST_ROOT/secret.asc" > "$WORK_DIR/mixed"
  PUBLIC_KEY="$WORK_DIR/mixed"; validate_public_key
' 1 'Public key mismatch'
run_case archive_late_failure '
  real_age="$AGE"
  bad_age() { "$real_age" --decrypt -i "$TEST_ROOT/age-key" "$2"; return 1; }
  AGE=bad_age; RECOVERY_ARCHIVE="$TEST_ROOT/recovery.tar.age"; validate_public_key
' 1 'Archive public-key extraction failed'
run_case symlink_ancestor '
  mkdir "$HOME/other"; ln -s "$HOME/other" "$HOME/link"
  TARGET="$HOME/link/store"; require_new_store
' 1 'Symlink in a sensitive'
run_case card_wrong_slot '
  printf "S APPTYPE piv\nS KEYPAIRINFO %s PIV.82 e\nOK\n" "$KEYGRIP" > "$WORK_DIR/card"
  validate_card_info "$WORK_DIR/card"
' 1 'expected PIV 9D key'
run_case shadow_wrong_slot '
  printf "S KEYINFO %s T serial PIV.82 - - -\nOK\n" "$KEYGRIP" > "$WORK_DIR/card"
  validate_shadow_info "$WORK_DIR/card"
' 1 'Expected a PIV 9D shadow'
run_case mkdir_race '
  validate_store
  require_new_store() { mkdir "$TARGET"; printf original > "$TARGET/sentinel"; }
  install_store
' 1 'Destination appeared'
[[ "$(< "$LAST_CASE_HOME/.password-store/sentinel")" == original ]] || fail 'mkdir race changed existing data'
run_case pass_failure '
  validate_store; validate_public_key
  user_gpg --batch --pinentry-mode loopback --passphrase "" --import "$TEST_ROOT/secret.asc" >/dev/null 2>&1
  mock_card_tools; restore_gpg
  # env invokes an executable mock, never the real user store or shell.
  printf "#!/bin/sh\nprintf synthetic-pass-secret\nexit 1\n" > "$WORK_DIR/bad-pass"
  chmod 700 "$WORK_DIR/bad-pass"; PASS="$WORK_DIR/bad-pass"
  verify_store
' 1 'pass show failed'
[[ ! -e "$LAST_CASE_HOME/.password-store" ]] || fail 'failed pass installed a store'

# A full --check entry-point run must neither initialize GPG nor create a lock.
CHECK_HOME="$TEST_ROOT/check-home"
mkdir -p "$CHECK_HOME/.gnupg"
chmod 700 "$CHECK_HOME/.gnupg"
printf 'application-priority piv\n' > "$CHECK_HOME/.gnupg/scdaemon.conf"
/usr/bin/env HOME="$CHECK_HOME" GNUPGHOME="$CHECK_HOME/.gnupg" /bin/bash "$REPO/scripts/restore-pass.sh" \
  --check --bundle "$TEST_ROOT/store.bundle" --public-key "$TEST_ROOT/public.asc" \
  --primary-fingerprint "$PRIMARY_FPR" --encryption-fingerprint "$ENCRYPTION_FPR" \
  --keygrip "$KEYGRIP" --test-entry test > "$TEST_ROOT/check-output" 2>&1
[[ "$(find "$CHECK_HOME" -type f | wc -l | tr -d ' ')" == 1 ]] || fail '--check wrote files'
[[ "$(find "$CHECK_HOME" -mindepth 1 -type d | wc -l | tr -d ' ')" == 1 ]] || fail '--check wrote directories'
printf 'PASS: read_only_check\n'
passed=$((passed + 1))
printf 'All %s restore-pass tests passed (no real keys/cards/stores used).\n' "$passed"
