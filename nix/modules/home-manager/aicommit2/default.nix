{ pkgs, config, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  aicommit2Base = inputs.aicommit2.packages.${system}.default;

  # FIXME: issue: build fails due to pnpmDeps hash mismatch (https://github.com/NixOS/nixpkgs/issues/397412)
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
    includeBody=false
    codeReview=false
    modelNameDisplay=short
    diffCompression=compact

    [OPENAI]
    model=gpt-4o-mini
    envKey=OPENAI_API_KEY
    maxTokens=1024

    [COPILOT_SDK]
    disabled=true
  '';
  sops.secrets.openai_api_key = {
    sopsFile = ../../../../secrets/darwin.yaml;
  };
}
