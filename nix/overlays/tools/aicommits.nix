{ ... }:

final: prev:
let
  pnpm = prev.pnpm_10;
in
{
  aicommits = prev.stdenvNoCC.mkDerivation rec {
    pname = "aicommits";
    version = "4.1.1";
    src = prev.fetchFromGitHub {
      owner = "Nutlope";
      repo = "aicommits";
      rev = "v${version}";
      # hash = prev.lib.fakeHash;
      hash = "sha256-W3+nXPJm5sCBozM3ZhreD9AQql8y+L+qe34JWe8Volo=";
    };
    pnpmDeps = prev.fetchPnpmDeps {
      inherit pname version src;
      inherit pnpm;
      fetcherVersion = 3;
      # hash = prev.lib.fakeHash;
      hash = "sha256-wDJ9unTtRX0Mwigm+zMibScyFM9oUmVYuIz5esSya/A=";
    };
    nativeBuildInputs = [
      prev.nodejs_24
      pnpm
      prev.pnpmConfigHook
    ];
    postPatch = ''
      substituteInPlace package.json \
        --replace-fail \
          '"version": "0.0.0-semantic-release"' \
          '"version": "${version}"'
    '';
    buildPhase = ''
      runHook preBuild
      pnpm build
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/aicommits"
      mkdir -p "$out/bin"
      cp -R dist "$out/lib/aicommits/"
      chmod +x "$out/lib/aicommits/dist/cli.mjs"
      patchShebangs "$out/lib/aicommits/dist/cli.mjs"
      ln -s "$out/lib/aicommits/dist/cli.mjs" "$out/bin/aicommits"
      ln -s "$out/lib/aicommits/dist/cli.mjs" "$out/bin/aic"
      runHook postInstall
    '';
    nativeInstallCheckInputs = [
      prev.versionCheckHook
    ];
    doInstallCheck = true;
    versionCheckProgramArg = "--version";
    meta = {
      mainProgram = "aicommits";
      description = "A CLI that writes git commit messages with AI";
      homepage = "https://github.com/Nutlope/aicommits";
      license = prev.lib.licenses.mit;
    };
  };
}
