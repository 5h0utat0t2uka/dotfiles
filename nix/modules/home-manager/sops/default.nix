{ config, pkgs, ... }:

{
  home.packages = [
    pkgs.sops
  ];

  home.sessionVariables = {
    SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  };

  # sops = {
  #   age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  #   defaultSopsFile = ../../secrets/darwin.yaml;
  #   secrets = {
  #     "cloudflare/api_token" = { };
  #   };
  # };
}
