{ config, pkgs, ... }:

let
  ageKeyPath = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
in
{
  home.packages = [
    pkgs.sops
    pkgs.age
  ];
  home.sessionVariables = { SOPS_AGE_KEY_FILE = ageKeyPath; };
  sops.age.keyFile = ageKeyPath;
}
