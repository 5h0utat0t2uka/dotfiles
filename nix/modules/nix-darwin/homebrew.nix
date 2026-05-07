{ ... }:

{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
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
