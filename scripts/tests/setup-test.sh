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
  local case_home="${4:-}"
  local case_environment=(/usr/bin/env)
  mkdir "$TEST_ROOT/$name"
  if [[ -n "$case_home" ]]; then
    mkdir -p "$case_home"
    case_environment=(/usr/bin/env "HOME=$case_home"
      "XDG_CONFIG_HOME=$case_home/.config" "XDG_DATA_HOME=$case_home/.local/share"
      "XDG_CACHE_HOME=$case_home/.cache" "XDG_STATE_HOME=$case_home/.local/state"
      GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1)
  fi
  "${case_environment[@]}" /bin/bash -c '
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
  if grep -qE 'AGE-SECRET-KEY-|synthetic secret' "$TEST_ROOT/$name/output"; then fail "$name printed a secret"; fi
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
grep -q 'SOPS decryption failed (exit ' "$TEST_ROOT/sops_wrong_key/output" || fail 'missing SOPS exit status'

run_case sops_missing_file '
  REPO_DIR="$TEST_ROOT/chezmoi-source"; SOPS_KEY="$TEST_ROOT/key.txt"
  "$TOOLS/jq" -n --arg file "$TEST_ROOT/missing.json" '\''{sopsFiles: [$file]}'\'' > "$WORK_DIR/config.json"
  validate_decryption
' 1
grep -q 'SOPS input is missing, not a regular file, or unreadable:' "$TEST_ROOT/sops_missing_file/output" || fail 'missing SOPS path diagnostic'

# Use the production projection with a minimal flake and lazy trees enabled.
# Only ciphertext and the flake are Git-tracked/copied to the Nix store.
mkdir "$TEST_ROOT/sops-flake"
cp "$TEST_ROOT/sops.json" "$TEST_ROOT/sops-flake/secrets.json"
cat > "$TEST_ROOT/sops-flake/flake.nix" <<'NIX'
{
  outputs = { self }: {
    darwinConfigurations.test.config = {
      system.primaryUser = "test";
      nixpkgs.hostPlatform.system = "aarch64-darwin";
      users.users.test = { home = "/Users/test"; shell = "/bin/zsh"; };
      nix.enable = false;
      home-manager.users.test.sops = {
        age.keyFile = "/Users/test/.config/sops/age/keys.txt";
        secrets.test = {
          sopsFile = ./secrets.json;
          path = "/Users/test/.config/test-secret";
          mode = "0400";
        };
        templates = {};
      };
      environment.etc = {};
      homebrew.onActivation = { autoUpdate = false; upgrade = false; cleanup = "none"; };
    };
  };
}
NIX
git -C "$TEST_ROOT/sops-flake" init -q
git -C "$TEST_ROOT/sops-flake" add flake.nix secrets.json
run_case sops_lazy_tree_path '
  nix_with_lazy_trees() {
    /nix/var/nix/profiles/default/bin/nix --option lazy-trees true "$@"
  }
  NIX=nix_with_lazy_trees
  FLAKE_DIR="$TEST_ROOT/sops-flake"; HOST_KEY=test
  REPO_DIR="$TEST_ROOT/sops-flake"; SOPS_KEY="$TEST_ROOT/key.txt"
  evaluate_host_configuration
  encrypted_path="$("$TOOLS/jq" -er '\''.sopsFiles[0]'\'' "$WORK_DIR/config.json")"
  [[ "$encrypted_path" == /nix/store/* && -f "$encrypted_path" && -r "$encrypted_path" ]]
  cmp -s "$encrypted_path" "$TEST_ROOT/sops.json"
  validate_decryption
'

# Use a disposable HOME so normal chezmoi commands exercise the default state
# location, with no --config/--persistent-state flags and no real user data.
set_chezmoi_test_paths() {
  REPO_DIR="$HOME/.local/share/chezmoi"
  CHEZMOI_CONFIG="$HOME/.config/chezmoi/chezmoi.toml"
  # shellcheck disable=SC2034 # Used by the sourced setup.sh functions.
  CHEZMOI_KEY="$HOME/.config/chezmoi/age-key.txt"
}

prepare_chezmoi_fixture() {
  set_chezmoi_test_paths
  mkdir -p "$REPO_DIR/private_dot_ssh" "$REPO_DIR/dot_config/ghostty" "${CHEZMOI_CONFIG%/*}"
  sed "s/^recipient = .*/recipient = \"$RECIPIENT\"/" \
    "$REPO/.chezmoi.toml.tmpl" > "$REPO_DIR/.chezmoi.toml.tmpl"
  printf 'Host test.example\n  HostName 192.0.2.1\n# synthetic secret\n' \
    | "$TOOLS/age" -r "$RECIPIENT" > "$REPO_DIR/private_dot_ssh/encrypted_private_config.age"
  printf 'synthetic secret key handle\n' \
    | "$TOOLS/age" -r "$RECIPIENT" > "$REPO_DIR/private_dot_ssh/encrypted_private_id_ed25519_sk_test.age"
  printf '# synthetic public key placeholder\n' > "$REPO_DIR/private_dot_ssh/id_ed25519_sk_test.pub"
  printf 'font-size = 14\n' > "$REPO_DIR/dot_config/ghostty/config.ghostty"
  printf '%s\n' '#!/bin/sh' 'printf "ran\n" >> "$HOME/bootstrap-runs"' \
    > "$REPO_DIR/run_once_before_test.sh"
  git -C "$REPO_DIR" init -q
  git -C "$REPO_DIR" add .
  git -C "$REPO_DIR" -c user.name=bootstrap-test -c user.email=test@example.invalid \
    -c commit.gpgsign=false commit -qm fixture
  # shellcheck disable=SC2034 # Used by assert_clean_source in setup.sh.
  SOURCE_REV="$(git -C "$REPO_DIR" rev-parse HEAD)"
}
export -f set_chezmoi_test_paths prepare_chezmoi_fixture

run_case init_without_identity '
  prepare_chezmoi_fixture
  validate_chezmoi_configuration
  [[ ! -e "$CHEZMOI_CONFIG" && ! -e "$CHEZMOI_KEY" && ! -e "$HOME/.ssh" ]]
  state_path="$("$TOOLS/jq" -er .persistentState "$WORK_DIR/chezmoi-runtime.json")"
  [[ "$state_path" == "$HOME/"* && ! -e "$state_path" ]]
  "$TOOLS/jq" -e --arg home "$HOME/" '\''
    (.cacheDir | startswith($home)) and
    .git.autocommit == false and .git.autopush == false and .git.autoadd == false
    and .warnings.configFileTemplateHasChanged == true
    and .umask == 18
  '\'' "$WORK_DIR/chezmoi-runtime.json" >/dev/null
  assert_clean_source
' 0 "$TEST_ROOT/init_without_identity/home"

for scenario in fresh existing; do
  run_case "chezmoi_${scenario}_apply" '
    prepare_chezmoi_fixture
    validate_chezmoi_configuration
    cp "$TEST_ROOT/key.txt" "$CHEZMOI_KEY"
    if [[ "$1" == chezmoi_existing_apply ]]; then
      # Simulate old setup: config installed, but no normal initialization record.
      install -m 600 "$WORK_DIR/chezmoi.toml" "$CHEZMOI_CONFIG"
      config_inode="$(stat -f %i "$CHEZMOI_CONFIG")"
    fi
    apply_chezmoi_configuration
    [[ "$(umask)" == 0077 ]] || die "chezmoi changed the recovery shell umask."
    runtime_state="$("$TOOLS/jq" -er .persistentState "$WORK_DIR/chezmoi-runtime.json")"
    effective_state="$(cm --config "$WORK_DIR/chezmoi-runtime.json" dump-config --format json | "$TOOLS/jq" -er .persistentState)"
    normal_state="$("$TOOLS/chezmoi" dump-config --format json | "$TOOLS/jq" -er \
      --arg state "${CHEZMOI_CONFIG%/*}/chezmoistate.boltdb" '\''
        if .persistentState == "" then $state else .persistentState end
      '\'')"
    [[ "$runtime_state" == "$normal_state" ]] || die "State path mismatch: runtime=$runtime_state normal=$normal_state"
    [[ "$effective_state" == "$normal_state" ]] || die "Effective state path mismatch: effective=$effective_state normal=$normal_state"
    [[ -f "$normal_state" ]] || die "Normal state file was not created: $normal_state"
    cm --config "$WORK_DIR/chezmoi-runtime.json" state dump > "$WORK_DIR/runtime-state.json"
    "$TOOLS/chezmoi" state dump > "$WORK_DIR/normal-state.json"
    cmp -s "$WORK_DIR/runtime-state.json" "$WORK_DIR/normal-state.json" || die "State contents differ between normal and bootstrap commands."
    "$TOOLS/chezmoi" verify "$HOME/.ssh/config" 2> "$WORK_DIR/normal-verify-errors"
    [[ ! -s "$WORK_DIR/normal-verify-errors" ]] || die "Normal verify warned before workdir cleanup."
    cmp -s "$CHEZMOI_CONFIG" "$WORK_DIR/chezmoi.toml"
    [[ "$(stat -f %Lp "$CHEZMOI_CONFIG")" == 600 ]]
    [[ "$(stat -f %Lp "$HOME/.ssh")" == 700 ]]
    [[ "$(stat -f %Lp "$HOME/.ssh/config")" == 600 ]]
    [[ "$(stat -f %Lp "$HOME/.ssh/id_ed25519_sk_test")" == 600 ]]
    printf "Host test.example\n  HostName 192.0.2.1\n# synthetic secret\n" | cmp -s - "$HOME/.ssh/config"
    [[ "$(cat "$HOME/.ssh/id_ed25519_sk_test")" == "synthetic secret key handle" ]]
    [[ "$(cat "$HOME/bootstrap-runs")" == ran ]]
    if [[ -n "${config_inode:-}" ]]; then
      [[ "$(stat -f %i "$CHEZMOI_CONFIG")" == "$config_inode" ]]
    fi
    assert_clean_source
  ' 0 "$TEST_ROOT/chezmoi_${scenario}_apply/home"
  run_case "chezmoi_${scenario}_normal_commands" '
    fixture="${1%_normal_commands}_apply"
    set_chezmoi_test_paths
    # The setup workdir has already been removed by the production cleanup trap.
    [[ ! -e "$TEST_ROOT/$fixture/work" ]]
    umask 022
    "$TOOLS/chezmoi" verify
    [[ -z "$("$TOOLS/chezmoi" diff)" ]] || die "Normal diff is not empty."
    [[ -z "$("$TOOLS/chezmoi" status)" ]]
    "$TOOLS/chezmoi" --no-tty --error-on-conflict apply
    [[ "$(cat "$HOME/bootstrap-runs")" == ran ]]
    # A clean target can be updated without a conflict only if apply history survived.
    printf "Host test.example\n  HostName 192.0.2.2\n# synthetic secret\n" \
      | "$TOOLS/age" -r "$RECIPIENT" > "$REPO_DIR/private_dot_ssh/encrypted_private_config.age"
    validate_chezmoi_configuration
    cm --config "$WORK_DIR/chezmoi-runtime.json" --no-tty --error-on-conflict apply "$HOME/.ssh/config"
    printf "Host test.example\n  HostName 192.0.2.2\n# synthetic secret\n" | cmp -s - "$HOME/.ssh/config"
    apply_chezmoi_configuration
    [[ "$(cat "$HOME/bootstrap-runs")" == ran ]]
  ' 0 "$TEST_ROOT/chezmoi_${scenario}_apply/home"
  if grep -q 'config file template has changed' "$TEST_ROOT/chezmoi_${scenario}_apply/output" \
    "$TEST_ROOT/chezmoi_${scenario}_normal_commands/output"; then
    fail "chezmoi $scenario setup did not preserve the initialization record"
  fi
  for mask in 022 077 002; do
    run_case "chezmoi_${scenario}_permissions_umask_${mask}" '
      set_chezmoi_test_paths
      umask "${1##*_}"
      "$TOOLS/chezmoi" verify
      [[ -z "$("$TOOLS/chezmoi" diff)" ]]
      "$TOOLS/chezmoi" --no-tty --error-on-conflict apply
      [[ -z "$("$TOOLS/chezmoi" status)" ]]
      [[ "$(stat -f %Lp "$HOME/.config")" == 755 ]]
      [[ "$(stat -f %Lp "$HOME/.config/ghostty")" == 755 ]]
      [[ "$(stat -f %Lp "$HOME/.config/ghostty/config.ghostty")" == 644 ]]
      [[ "$(stat -f %Lp "$HOME/.ssh/id_ed25519_sk_test.pub")" == 644 ]]
      [[ "$(stat -f %Lp "$HOME/.ssh")" == 700 ]]
      [[ "$(stat -f %Lp "$HOME/.ssh/config")" == 600 ]]
      [[ "$(stat -f %Lp "$HOME/.ssh/id_ed25519_sk_test")" == 600 ]]
      [[ "$(stat -f %Lp "${CHEZMOI_CONFIG%/*}")" == 700 ]]
      [[ "$(stat -f %Lp "$CHEZMOI_CONFIG")" == 600 ]]
      [[ "$(stat -f %Lp "$CHEZMOI_KEY")" == 600 ]]
      [[ "$(cat "$HOME/bootstrap-runs")" == ran ]]
    ' 0 "$TEST_ROOT/chezmoi_${scenario}_apply/home"
  done
done

run_case chezmoi_legacy_permissions_migration '
  prepare_chezmoi_fixture
  cp "$REPO_DIR/.chezmoi.toml.tmpl" "$WORK_DIR/new-template"
  # Reproduce a setup made before the target umask was explicit.
  sed "/^umask = /d" "$WORK_DIR/new-template" > "$REPO_DIR/.chezmoi.toml.tmpl"
  cp "$TEST_ROOT/key.txt" "$CHEZMOI_KEY"
  # Deliberately bypass cm(), which now isolates chezmoi from umask 077.
  "$TOOLS/chezmoi" init
  "$TOOLS/chezmoi" --no-tty --error-on-conflict apply
  [[ "$(stat -f %Lp "$HOME/.config/ghostty")" == 700 ]]
  [[ "$(stat -f %Lp "$HOME/.config/ghostty/config.ghostty")" == 600 ]]
  [[ "$(stat -f %Lp "$HOME/.ssh/id_ed25519_sk_test.pub")" == 600 ]]

  # Simulate pulling the updated template, then the documented repair commands.
  cp "$WORK_DIR/new-template" "$REPO_DIR/.chezmoi.toml.tmpl"
  umask 022
  "$TOOLS/chezmoi" init
  "$TOOLS/chezmoi" dump-config --format json | "$TOOLS/jq" -e ".umask == 18" >/dev/null
  "$TOOLS/chezmoi" diff --exclude=scripts > "$WORK_DIR/permission-diff"
  grep -q "^old mode 100600$" "$WORK_DIR/permission-diff"
  grep -q "^new mode 100644$" "$WORK_DIR/permission-diff"
  "$TOOLS/chezmoi" --no-tty --error-on-conflict apply --exclude=scripts
  [[ "$(stat -f %Lp "$HOME/.config")" == 755 ]]
  [[ "$(stat -f %Lp "$HOME/.config/ghostty")" == 755 ]]
  [[ "$(stat -f %Lp "$HOME/.config/ghostty/config.ghostty")" == 644 ]]
  [[ "$(stat -f %Lp "$HOME/.ssh/id_ed25519_sk_test.pub")" == 644 ]]
  [[ "$(stat -f %Lp "$HOME/.ssh")" == 700 ]]
  [[ "$(stat -f %Lp "$HOME/.ssh/config")" == 600 ]]
  [[ "$(stat -f %Lp "$HOME/.ssh/id_ed25519_sk_test")" == 600 ]]
  [[ "$(stat -f %Lp "${CHEZMOI_CONFIG%/*}")" == 700 ]]
  [[ "$(stat -f %Lp "$CHEZMOI_CONFIG")" == 600 ]]
  [[ "$(stat -f %Lp "$CHEZMOI_KEY")" == 600 ]]
  [[ "$(cat "$HOME/bootstrap-runs")" == ran ]]
  for mask in 022 077 002; do
    umask "$mask"
    "$TOOLS/chezmoi" verify
    [[ -z "$("$TOOLS/chezmoi" diff)" ]]
  done
' 0 "$TEST_ROOT/chezmoi_legacy_permissions_migration/home"

run_case chezmoi_config_changed '
  prepare_chezmoi_fixture
  validate_chezmoi_configuration
  cp "$WORK_DIR/chezmoi.toml" "$CHEZMOI_CONFIG"
  printf "\n# user edit\n" >> "$CHEZMOI_CONFIG"
  apply_chezmoi_configuration
' 1 "$TEST_ROOT/chezmoi_config_changed/home"
grep -q '# user edit' "$TEST_ROOT/chezmoi_config_changed/home/.config/chezmoi/chezmoi.toml" || fail 'existing config was overwritten'
[[ ! -e "$TEST_ROOT/chezmoi_config_changed/home/.ssh" ]] || fail 'files applied despite config conflict'

run_case chezmoi_target_conflict '
  set_chezmoi_test_paths
  printf "# local synthetic secret\n" > "$HOME/.ssh/config"
  "$TOOLS/chezmoi" --no-tty --error-on-conflict apply "$HOME/.ssh/config"
' 1 "$TEST_ROOT/chezmoi_fresh_apply/home"
grep -q '^# local synthetic secret$' "$TEST_ROOT/chezmoi_fresh_apply/home/.ssh/config" || fail 'target conflict was overwritten'

run_case chezmoi_template_change_warns '
  set_chezmoi_test_paths
  printf "\n# later template change\n" >> "$REPO_DIR/.chezmoi.toml.tmpl"
  "$TOOLS/chezmoi" verify "$HOME/.ssh/config"
' 0 "$TEST_ROOT/chezmoi_existing_apply/home"
grep -q 'config file template has changed' "$TEST_ROOT/chezmoi_template_change_warns/output" || fail 'template warnings were suppressed'

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
