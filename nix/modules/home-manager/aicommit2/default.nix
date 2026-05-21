{ pkgs, config, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  aicommit2Base = inputs.aicommit2.packages.${system}.default;
  aicommit2 = aicommit2Base.overrideAttrs (old: {
    pnpmDeps = pkgs.pnpm.fetchDeps {
      inherit (old) pname version src;
      fetcherVersion = 3;
      hash = "sha256-C1tNiXY/klHO5CqNpOq+vF9qZJ1ShOOmvqnMInacgKo=";
    };
  });
  apiKey = config.sops.secrets.openai_api_key.path;
  mkAicommit2Wrapper = name: target: pkgs.writeShellScriptBin name ''
    export OPENAI_API_KEY="$(${pkgs.coreutils}/bin/cat ${apiKey})"
    exec ${aicommit2}/bin/${target} "$@"
  '';
in
{
  home.packages = [
    (mkAicommit2Wrapper "aicommit2" "aicommit2")
    (mkAicommit2Wrapper "aic2" "aic2")
    (mkAicommit2Wrapper "aic" "aic2")
  ];

  xdg.configFile."aicommit2/config.ini".text = ''
    type=conventional
    locale=en
    generate=1
    timeout=60000
    modelNameDisplay=short
    diffCompression=compact
    maxHunkLines=200
    maxDiffLines=1000
    diffContext=1

    [OPENAI]
    model=gpt-5-mini
    envKey=OPENAI_API_KEY
    maxTokens=1024
    temperature=0.2
    topP=0.9
  '';
  sops.secrets.openai_api_key = {
    sopsFile = ../../../../secrets/darwin.yaml;
  };
}
