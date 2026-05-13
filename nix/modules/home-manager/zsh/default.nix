{ config, pkgs, lib, ... }:

{
  xdg.enable = true;
  programs.zsh = {
    enable = true;
    enableCompletion = false;
    dotDir = "${config.xdg.configHome}/zsh";
    defaultKeymap = "emacs";
    profileExtra = builtins.readFile ./zprofile;
    envExtra = ''
      export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
      export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
      export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
    '';
    sessionVariables = {
      SHELL_SESSIONS_DIR = "${config.xdg.cacheHome}/zsh/sessions";
      ABBR_USER_ABBREVIATIONS_FILE = "${config.xdg.configHome}/zsh-abbr/user-abbreviations";
      ABBR_SET_EXPANSION_CURSOR = "1";
      ABBR_SET_LINE_CURSOR = "1";
      ABBR_EXPANSION_CURSOR_MARKER = "@";
      ABBR_LINE_CURSOR_MARKER = "@";
    };
    setOptions = [
      "HIST_IGNORE_ALL_DUPS"
      "HIST_FIND_NO_DUPS"
      "HIST_REDUCE_BLANKS"
      "HIST_VERIFY"
      "HIST_IGNORE_SPACE"
      "SHARE_HISTORY"
      "AUTO_PUSHD"
      "PUSHD_IGNORE_DUPS"
      "INTERACTIVE_COMMENTS"
    ];
    history = {
      path = "${config.xdg.cacheHome}/zsh/.zsh_history";
      size = 10000;
      save = 10000;
    };
    autosuggestion = {
      enable = true;
      strategy = [ "history" ];
    };
    syntaxHighlighting = {
      enable = true;
    };
    zsh-abbr = {
      enable = true;
      abbreviations = {
        gs = "git status";
        gd = "git diff";
        ga = "git add .";
        gc = ''git commit -m "@"'';
        gp = "git push origin HEAD";
        gl = "git log --graph --all --decorate --pretty=format:'%C(magenta)%h%Creset %C(blue)%ad%Creset %C(green)%an%Creset %s%C(red)%d%Creset' --date=short";
        nri = "ni";
        nrf = "ni --frozen";
        nrd = "nr dev";
        nrb = "nr build";
        nrs = "nr start";
        ll = "eza -alo --time-style iso";
        lg = "lazygit";
      };
    };
    shellAliases = {
      ".." = "cd ..";
      vpn = "${config.home.homeDirectory}/Development/scripts/vpn/connect.sh";
      webp = "${config.home.homeDirectory}/Development/scripts/webp.sh";
    };
    initContent = lib.mkMerge [
      (lib.mkBefore ''
        CACHE_DIR="''${XDG_CACHE_HOME}/zsh"
        mkdir -p "$CACHE_DIR"
        mkdir -p "$SHELL_SESSIONS_DIR"

        typeset -U fpath
        fpath=(
          "${config.home.profileDirectory}/share/zsh/site-functions"(N-/)
          "''${NIX_PROFILE_PREFIX:-}/share/zsh/site-functions"(N-/)
          $fpath
        )

        zstyle ':completion:*' use-cache on
        zstyle ':completion:*' cache-path "$CACHE_DIR/.zcompcache"
        autoload -Uz compinit
        dump="$CACHE_DIR/.zcompdump-''${ZSH_VERSION}"
        if [[ -f "$dump.zwc" ]] && [[ "$dump.zwc" -nt "$dump" ]]; then
          compinit -C -d "$dump"
        else
          compinit -d "$dump"
          [[ -f "$dump" ]] && zcompile "$dump"
        fi
      '')
      (builtins.readFile ./zshrc)
    ];
  };
  home.packages = with pkgs; [
    zsh-completions
  ];
}
