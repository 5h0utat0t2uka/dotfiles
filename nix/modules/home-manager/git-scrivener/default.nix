{ config, inputs, lib, pkgs, ... }:

let
  scrivener =
    inputs.git-scrivener.packages.${pkgs.stdenv.hostPlatform.system}.git-scrivener;
in
{
  # 既存の暗号化ファイルにあるAPIキーを利用する
  sops.secrets.openai_api_key = {
    sopsFile = ../../../../secrets/darwin.yaml;
    mode = "0600";
  };

  # APIキーを用意してCLI本体を起動するコマンドを導入する
  home.packages = [
    (pkgs.writeShellApplication {
      name = "git-scrivener";

      text = ''
        OPENAI_API_KEY="$(< ${lib.escapeShellArg config.sops.secrets.openai_api_key.path})"
        export OPENAI_API_KEY
        exec "${scrivener}/bin/git-scrivener" "$@"
      '';
    })
  ];
}
