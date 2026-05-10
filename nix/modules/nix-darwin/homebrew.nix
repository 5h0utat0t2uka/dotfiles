{ ... }:

{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
      # NOTE: chore: update homebrew to 5.1.10 (https://github.com/zhaofengli/nix-homebrew/pull/136)
      # extraEnv = {
      #   HOMEBREW_NO_INSTALL_FROM_API = "1";
      # };
    };
    taps = [];
    brews = [
      # FIXME: issue: samba build failure (https://github.com/NixOS/nixpkgs/issues/494532)
      "termscp"
    ];
    casks = [
      "codex-app"
      "karabiner-elements"
      "ollama-app"
      "zed"
    ];
  };
}
