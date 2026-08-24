{ config, pkgs, lib, identity, ... }:

let
  # 優先順位順にGit署名鍵を定義
  # 3本目以降を追加する場合も、ここに追加する
  signingKeys = [
    "${config.home.homeDirectory}/.ssh/id_ed25519_sk_git_sign_primary"
    "${config.home.homeDirectory}/.ssh/id_ed25519_sk_git_sign_secondary"
  ];
  sshSign = pkgs.writeShellApplication {
    name = "ssh-sign-yubikey";
    runtimeInputs = [
      pkgs.openssh
    ];

    text = ''
      # gpg.ssh.program は署名だけでなく検証にも利用される
      # signing key の差し替えは `ssh-keygen -Y sign` の場合だけ行う
      args=("$@")
      is_sign=false
      for ((i = 0; i + 1 < ''${#args[@]}; i++)); do
        if [[ "''${args[$i]}" == "-Y" &&
              "''${args[$((i + 1))]}" == "sign" ]]; then
          is_sign=true
          break
        fi
      done
      # verify などsign以外の処理は、そのままssh-keygenへ渡す
      if [[ "$is_sign" != true ]]; then
        exec ssh-keygen "''${args[@]}"
      fi

      # Gitから渡された `-f <signing-key>` の位置を取得する
      key_index=-1
      for ((i = 0; i + 1 < ''${#args[@]}; i++)); do
        if [[ "''${args[$i]}" == "-f" ]]; then
          key_index=$((i + 1))
          break
        fi
      done
      if [[ "$key_index" -eq -1 ]]; then
        echo "ssh-keygen signing key argument (-f) was not found." >&2
        exit 1
      fi

      # Nix側で定義した署名鍵をShell配列へ展開する
      signing_keys=(
        ${lib.escapeShellArgs signingKeys}
      )

      # 優先順位順に署名を試行
      # Primary YubiKeyが利用可能: Primaryで成功して終了
      # Primaryが利用不可でSecondaryが利用可能: Primaryは失敗 → Secondaryで成功
      # どちらも利用不可: 全候補が失敗してエラー
      for key in "''${signing_keys[@]}"; do
        # key handle自体が存在しない候補はスキップ
        [[ -f "$key" ]] || continue
        args[key_index]="$key"
        if ssh-keygen "''${args[@]}"; then
          exit 0
        fi
      done
      echo "No available Git signing key could sign." >&2
      exit 1
    '';
  };
in
{
  programs.git = {
    enable = true;
    signing = {
      # GitにはPrimaryをデフォルト値として設定する
      # 実際の署名時はsshSignが利用可能な鍵へ自動的に切り替え
      key = builtins.head signingKeys;
      format = "ssh";
      signByDefault = true;
      signer = "${sshSign}/bin/ssh-sign-yubikey";
    };
    ignores = [
      ".DS_Store"
      "**/.claude/settings.local.json"
    ];
    settings = {
      user = {
        name = identity.git.user.name;
        email = identity.git.user.email;
      };
      core = {
        editor = "vim";
        pager = "delta";
      };
      gpg = {
        ssh = {
          allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
        };
      };
      url."git@github.com:" = {
        insteadOf = "https://github.com/";
      };
      alias = {
        sync = "!git fetch origin && git switch dev && git pull --ff-only origin dev && git merge origin/main && git push origin dev";
      };
      interactive = { diffFilter = "delta --color-only"; };
      merge = { conflictstyle = "diff3"; };
      diff = { colorMoved = "default"; };
      init = { defaultBranch = "main"; };
      push = { autoSetupRemote = true; };
      delta = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        syntax-theme = "Nord";
        file-style = "bold green";
        file-decoration-style = "none";
        line-numbers-left-format = "{nm:>4} ";
        line-numbers-right-format = "{np:>4} ";
        hunk-header-decoration-style = "none";
      };
      ghq = {
        user = identity.git.user.name;
        root = "${identity.homeDirectory}/Development/repositories";
      };
    };
  };

  xdg.configFile."git/allowed_signers".source = ./allowed_signers;
  home.packages = with pkgs; [
    delta
    ghq
  ];
}
