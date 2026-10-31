{ config, inputs, lib, pkgs, ... }:

let
  scrivener = inputs.git-scrivener.packages.${pkgs.stdenv.hostPlatform.system}.git-scrivener;
in
{
  imports = [
    inputs.git-scrivener.homeManagerModules.default
  ];

  sops.secrets.openai_api_key = {
    sopsFile = ../../../../secrets/darwin.yaml;
    mode = "0600";
  };

  programs.git-scrivener = {
    enable = true;
    provider = "openai";
    language = "en";
    model = "gpt-6-luna";
    package = pkgs.writeShellApplication {
      name = "git-scrivener";
      text = ''
        OPENAI_API_KEY="$(< ${lib.escapeShellArg config.sops.secrets.openai_api_key.path})"
        export OPENAI_API_KEY
        exec "${scrivener}/bin/git-scrivener" "$@"
      '';
    };
  };
}
