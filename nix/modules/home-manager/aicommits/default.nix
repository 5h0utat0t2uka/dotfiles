{ pkgs, config, ... }:

{
  home.packages = [
    pkgs.aicommits
  ];
  sops.secrets.openai_api_key = {
    sopsFile = ../../../../secrets/darwin.yaml;
  };
  sops.templates.aicommits = {
    path = "${config.home.homeDirectory}/.aicommits";
    mode = "0600";
    content = ''
      OPENAI_API_KEY=${config.sops.placeholder.openai_api_key}
      OPENAI_MODEL=gpt-4o-mini
      type=conventional
      locale=en
      generate=1
      timeout=60000
    '';
  };
}
