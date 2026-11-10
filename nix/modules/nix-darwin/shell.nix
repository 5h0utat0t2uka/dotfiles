{
  pkgs,
  lib,
  identity,
  ...
}:

let
  userShell = "${pkgs.zsh}/bin/zsh";
in
{
  users.users.${identity.username} = {
    home = identity.homeDirectory;
    shell = userShell;
  };
  environment.shells = [
    pkgs.zsh
  ];
  programs.zsh = {
    enable = true;
    promptInit = "";
    enableCompletion = false;
    enableGlobalCompInit = false;
  };

  # Keep system zsh startup minimal.
  # User zsh initialization is managed by Home Manager.
  environment.etc."zshrc".text = lib.mkForce ''
    if [ -n "$__ETC_ZSHRC_SOURCED" -o -n "$NOSYSZSHRC" ]; then
      return
    fi
    __ETC_ZSHRC_SOURCED=1
    if test -f /etc/zshrc.local; then
      source /etc/zshrc.local
    fi
  '';
}
