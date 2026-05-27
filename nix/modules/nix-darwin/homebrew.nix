{ config, ... }:

{
  environment.variables = {
    HOMEBREW_NO_ANALYTICS = "1";
  };
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
      extraEnv = {
        HOMEBREW_NO_ANALYTICS = "1";
        # NOTE: issue: update homebrew to 5.1.10 (https://github.com/zhaofengli/nix-homebrew/pull/136)
        # HOMEBREW_NO_INSTALL_FROM_API = "1";
      };
    };
    taps = builtins.attrNames config.nix-homebrew.taps;
    brews = [
      # FIXME: issue: samba build failure (https://github.com/NixOS/nixpkgs/issues/494532)
      "termscp"
    ];

    # casks = map (name: { inherit name; greedy = true; }) [];
    casks = [
      { name = "codex-app"; greedy = true; }
      { name = "claude"; greedy = true; }
      { name = "ghostty"; greedy = false; }
      { name = "karabiner-elements"; greedy = false; }
      { name = "ollama-app"; greedy = true; }
      { name = "zed"; greedy = true; }
    ];
  };
}
