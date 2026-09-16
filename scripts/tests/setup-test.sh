#!/bin/bash
# macOS-only integration tests using generated identities and disposable data.
# Never read real identities or run sudo, activation, or Homebrew.
# Test bodies expand their variables in the child shell.
# shellcheck disable=SC2016
set -euo pipefail
umask 077
REPO="$(cd "$(dirname "$0")/../.." && pwd -P)"
TOOLS_ROOT="${1:?Pass the store path of the bootstrap-tools package}"
[[ -x "$TOOLS_ROOT/bin/age" && -x "$TOOLS_ROOT/bin/chezmoi" ]] || exit 1
TEST_ROOT="$(mktemp -d "$REPO/scripts/tests/.setup-test.XXXXXXXX")"
trap '/bin/rm -rf -- "$TEST_ROOT"' EXIT
export TEST_ROOT TOOLS_ROOT REPO
passed=0

fail() { printf >&2 'FAIL: %s\n' "$*"; exit 1; }
ok() { printf 'PASS: %s\n' "$*"; passed=$((passed + 1)); }

"$TOOLS_ROOT/bin/age-keygen" -o "$TEST_ROOT/key.txt" 2>/dev/null
"$TOOLS_ROOT/bin/age-keygen" -o "$TEST_ROOT/other-key.txt" 2>/dev/null
RECIPIENT="$("$TOOLS_ROOT/bin/age-keygen" -y "$TEST_ROOT/key.txt")"
export RECIPIENT
mkdir "$TEST_ROOT/mock-bin"
ln -s "$TOOLS_ROOT/bin/age-keygen" "$TEST_ROOT/mock-bin/age-keygen"
ln -s "$TOOLS_ROOT/bin/ln" "$TEST_ROOT/mock-bin/ln"
# Only the interactive backup decryption is mocked; validation uses real age.
printf '%s\n' '#!/bin/bash' 'cat "$TEST_ROOT/key.txt"' > "$TEST_ROOT/mock-bin/age"
chmod 700 "$TEST_ROOT/mock-bin/age"

run_case() {
  local name="$1" body="$2" expected="${3:-0}" result=0
  mkdir "$TEST_ROOT/$name"
  /bin/bash -c '
    source "$REPO/scripts/setup.sh"
    WORK_DIR="$TEST_ROOT/$1/work"
    mkdir "$WORK_DIR"
    TOOLS="$TOOLS_ROOT/bin"
    STAGE=test
    eval "$2"
  ' test "$name" "$body" > "$TEST_ROOT/$name/output" 2>&1 || result=$?
  [[ "$result" == "$expected" ]] || {
    grep -E '^(chezmoi:|jq:|ERROR|error:|Conflicting file:)' "$TEST_ROOT/$name/output" >&2 || true
    fail "$name exited $result, expected $expected"
  }
  [[ ! -e "$TEST_ROOT/$name/work" ]] || fail "$name left its work directory"
  if grep -q 'AGE-SECRET-KEY-' "$TEST_ROOT/$name/output"; then fail "$name printed a private key"; fi
  ok "$name"
}

run_case valid_existing 'validate_identity "$TEST_ROOT/key.txt" "$RECIPIENT"'
run_case wrong_identity 'validate_identity "$TEST_ROOT/other-key.txt" "$RECIPIENT"' 1
run_case missing_backup 'check_identity_input "$TEST_ROOT/missing.txt" "" --chezmoi-backup' 1
run_case readable_backup 'check_identity_input "$TEST_ROOT/missing.txt" "$TEST_ROOT/key.txt" --chezmoi-backup'

ln -s "$TEST_ROOT/key.txt" "$TEST_ROOT/symlink.txt"
run_case symlink_rejected 'check_identity_input "$TEST_ROOT/symlink.txt" "" --chezmoi-backup' 1
ln "$TEST_ROOT/other-key.txt" "$TEST_ROOT/hardlink.txt"
run_case hardlink_rejected 'check_identity_input "$TEST_ROOT/hardlink.txt" "" --chezmoi-backup' 1
cp "$TEST_ROOT/key.txt" "$TEST_ROOT/public-mode.txt"
chmod 644 "$TEST_ROOT/public-mode.txt"
run_case permissions_rejected 'check_identity_input "$TEST_ROOT/public-mode.txt" "" --chezmoi-backup' 1

run_case restore 'TOOLS="$TEST_ROOT/mock-bin"; recover_identity "$TEST_ROOT/restored/key.txt" unused "$RECIPIENT" test'
cmp -s "$TEST_ROOT/key.txt" "$TEST_ROOT/restored/key.txt" || fail 'restored content differs'
[[ "$(stat -f '%Lp' "$TEST_ROOT/restored/key.txt")" == 600 ]] || fail 'identity mode'
[[ "$(stat -f '%Lp' "$TEST_ROOT/restored")" == 700 ]] || fail 'directory mode'
[[ "$(stat -f '%l' "$TEST_ROOT/restored/key.txt")" == 1 ]] || fail 'remaining hard link'
run_case rerun 'recover_identity "$TEST_ROOT/restored/key.txt" /nonexistent "$RECIPIENT" test'
run_case wrong_restoration 'TOOLS="$TEST_ROOT/mock-bin"; recover_identity "$TEST_ROOT/wrong/key.txt" unused age1wrong test' 1
[[ ! -e "$TEST_ROOT/wrong/key.txt" ]] || fail 'wrong identity was installed'
[[ -z "$(find "$TEST_ROOT/wrong" -name '.setup-age.*' -print)" ]] || fail 'wrong identity temporary file remains'

printf '%s\n' '#!/bin/bash' 'printf "partial-secret"' 'exit 1' > "$TEST_ROOT/mock-bin/age"
run_case failed_decryption 'TOOLS="$TEST_ROOT/mock-bin"; recover_identity "$TEST_ROOT/partial/key.txt" unused "$RECIPIENT" test' 1
[[ ! -e "$TEST_ROOT/partial/key.txt" ]] || fail 'partial identity was installed'
[[ -z "$(find "$TEST_ROOT/partial" -name '.setup-age.*' -print)" ]] || fail 'partial plaintext remains'
! grep -q 'partial-secret' "$TEST_ROOT/failed_decryption/output" || fail 'partial plaintext was logged'

printf '%s\n' '#!/bin/bash' 'cat "$TEST_ROOT/key.txt"' 'mkdir "$TEST_ROOT/collision/key.txt"' > "$TEST_ROOT/mock-bin/age"
run_case concurrent_directory 'TOOLS="$TEST_ROOT/mock-bin"; recover_identity "$TEST_ROOT/collision/key.txt" unused "$RECIPIENT" test' 1
[[ -z "$(find "$TEST_ROOT/collision" -name '.setup-age.*' -print)" ]] || fail 'a key was written into the concurrent directory'

printf '%s\n' '#!/bin/bash' 'printf "partial-secret"' 'kill -TERM "$PPID"' > "$TEST_ROOT/mock-bin/age"
run_case interrupted_decryption 'TOOLS="$TEST_ROOT/mock-bin"; recover_identity "$TEST_ROOT/interrupted/key.txt" unused "$RECIPIENT" test' 143
[[ -z "$(find "$TEST_ROOT/interrupted" -name '.setup-age.*' -print)" ]] || fail 'interrupted recovery left plaintext'

# Genuine age encryption/decryption exercises all tracked encrypted source files.
mkdir "$TEST_ROOT/source"
git -C "$TEST_ROOT/source" init -q
printf 'synthetic secret\n' | "$TOOLS_ROOT/bin/age" -r "$RECIPIENT" > "$TEST_ROOT/source/encrypted_private_test.age"
git -C "$TEST_ROOT/source" add encrypted_private_test.age
run_case verify_encrypted_files '
  REPO_DIR="$TEST_ROOT/source"; CHEZMOI_KEY="$TEST_ROOT/key.txt"
  printf "{\"sopsFiles\": []}" > "$WORK_DIR/config.json"
  validate_decryption
'
printf 'corrupted' > "$TEST_ROOT/source/encrypted_private_test.age"
run_case corrupt_ciphertext '
  REPO_DIR="$TEST_ROOT/source"; CHEZMOI_KEY="$TEST_ROOT/key.txt"
  printf "{\"sopsFiles\": []}" > "$WORK_DIR/config.json"
  validate_decryption
' 1

# A real SOPS fixture ensures only the explicitly supplied synthetic key works.
printf '{"test":"synthetic secret"}\n' > "$TEST_ROOT/plain.json"
"$TOOLS_ROOT/bin/sops" --config /dev/null --encrypt --age "$RECIPIENT" \
  "$TEST_ROOT/plain.json" > "$TEST_ROOT/sops.json"
run_case sops_decryption '
  REPO_DIR="$TEST_ROOT/chezmoi-source"; mkdir "$REPO_DIR"; git -C "$REPO_DIR" init -q
  SOPS_KEY="$TEST_ROOT/key.txt"
  "$TOOLS/jq" -n --arg file "$TEST_ROOT/sops.json" '\''{sopsFiles: [$file]}'\'' > "$WORK_DIR/config.json"
  validate_decryption
'
run_case sops_wrong_key '
  REPO_DIR="$TEST_ROOT/chezmoi-source"; SOPS_KEY="$TEST_ROOT/other-key.txt"
  "$TOOLS/jq" -n --arg file "$TEST_ROOT/sops.json" '\''{sopsFiles: [$file]}'\'' > "$WORK_DIR/config.json"
  validate_decryption
' 1

# Exercise chezmoi init with a missing config and missing identity. No real HOME writes.
mkdir "$TEST_ROOT/destination"
sed "s|~/.config/chezmoi/age-key.txt|$TEST_ROOT/missing-identity.txt|" \
  "$REPO/.chezmoi.toml.tmpl" > "$TEST_ROOT/chezmoi-source/.chezmoi.toml.tmpl"
printf 'synthetic secret\n' | "$TOOLS_ROOT/bin/age" -r "$RECIPIENT" > "$TEST_ROOT/chezmoi-source/encrypted_private_test.age"
run_case init_without_identity '
  REPO_DIR="$TEST_ROOT/chezmoi-source"
  "$TOOLS/chezmoi" --source "$REPO_DIR" --destination "$TEST_ROOT/destination" \
    --config "$WORK_DIR/config.toml" --cache "$WORK_DIR/cache" \
    --persistent-state "$WORK_DIR/state.boltdb" init
  "$TOOLS/chezmoi" --source "$REPO_DIR" --destination "$TEST_ROOT/destination" \
    --config "$WORK_DIR/config.toml" --cache "$WORK_DIR/cache" \
    --persistent-state "$WORK_DIR/state.boltdb" dump-config --format json \
    | "$TOOLS/jq" '\''.git.autocommit = false | .git.autopush = false | .git.autoadd = false'\'' > "$WORK_DIR/runtime.json"
  "$TOOLS/chezmoi" --config "$WORK_DIR/runtime.json" dump-config --format json \
    | "$TOOLS/jq" -e '\''.git.autocommit == false and .git.autopush == false'\'' >/dev/null
  cp "$TEST_ROOT/key.txt" "$TEST_ROOT/missing-identity.txt"
  "$TOOLS/chezmoi" --config "$WORK_DIR/runtime.json" status
  "$TOOLS/chezmoi" --config "$WORK_DIR/runtime.json" apply
  [[ "$(cat "$TEST_ROOT/destination/test")" == "synthetic secret" ]]
  [[ "$(stat -f %Lp "$TEST_ROOT/destination/test")" == 600 ]]
  [[ -z "$("$TOOLS/chezmoi" --config "$WORK_DIR/runtime.json" status)" ]]
'

run_case arguments_invalid 'parse_args --check --apply' 1
run_case backup_missing_argument 'parse_args --chezmoi-backup' 1
run_case arguments_spaces 'parse_args --check --chezmoi-backup "/path with spaces/key.age"; [[ "$CHEZMOI_BACKUP" == "/path with spaces/key.age" ]]'

run_case check_never_applies '
  preflight() { :; }
  prepare_workdir() { die "--check reached a modifying phase"; }
  main --check
'

if [[ "${2:-}" == --evaluate ]]; then
  # Evaluate the real flake but initialize chezmoi only against a disposable source.
  mkdir "$TEST_ROOT/config-source"
  git -C "$TEST_ROOT/config-source" init -q
  cp "$REPO/.chezmoi.toml.tmpl" "$REPO/.sops.yaml" "$TEST_ROOT/config-source/"
  run_case evaluated_configuration '
    REPO_DIR="$TEST_ROOT/config-source"; FLAKE_DIR="$REPO/nix"
    NIX=/nix/var/nix/profiles/default/bin/nix
    USER_NAME="$(id -un)"; HOST_KEY="$(scutil --get LocalHostName)"
    CHEZMOI_CONFIG="$WORK_DIR/absent.toml"
    CHEZMOI_KEY="$HOME/.config/chezmoi/age-key.txt"; SOPS_KEY="$HOME/.config/sops/age/keys.txt"
    validate_configuration
  '
fi
printf '\n%s tests passed. No real identities or system activation were used.\n' "$passed"
