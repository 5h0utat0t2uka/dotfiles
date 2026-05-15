{ pkgs, config, lib, ... }:

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
  # home.file.".aicommits".text = ''
  #   provider=openai
  #   OPENAI_MODEL=gpt-5-nano
  #   type=conventional
  #   locale=en
  #   generate=1
  # '';
  home.activation.writeAicommitsConfig =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      umask 077
      cat > "$HOME/.aicommits" <<EOF
provider=openai
OPENAI_API_KEY=$(cat ${config.sops.secrets.openai_api_key.path})
OPENAI_MODEL=gpt-5-nano
type=conventional
locale=en
generate=1
EOF
    '';
  sops.secrets.openai_api_key = {
    sopsFile = ../../../../secrets/darwin.yaml;
  };
}
