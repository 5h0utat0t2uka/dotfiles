{ pkgs, config, ... }:

let
  aicommits = pkgs.writeShellScriptBin "aicommits" ''
    export OPENAI_API_KEY="$(cat ${config.sops.secrets.openai_api_key.path})"
    exec ${pkgs.aicommits}/bin/aicommits "$@"
  '';
  aic = pkgs.writeShellScriptBin "aic" ''
    export OPENAI_API_KEY="$(cat ${config.sops.secrets.openai_api_key.path})"
    exec ${pkgs.aicommits}/bin/aic "$@"
  '';
in
{
  home.packages = [
    aicommits
    aic
  ];
  home.file.".aicommits".text = ''
    provider=openai
    type=conventional
    locale=en
    generate=1
  '';
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets.openai_api_key = {
      sopsFile = ../../../../secrets/darwin.yaml;
    };
  };
}
