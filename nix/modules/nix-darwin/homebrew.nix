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
        # HOMEBREW_NO_INSTALL_FROM_API = "1";
      };
    };
    taps = builtins.attrNames config.nix-homebrew.taps;
    brews = [
      "termscp"
      "quien"
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
