{ ... }:

final: prev: {
  aicommits = prev.buildNpmPackage rec {
    pname = "aicommits";
    version = "3.2.0";
    src = prev.fetchFromGitHub {
      owner = "Nutlope";
      repo = "aicommits";
      rev = "v${version}";
      hash = "sha256-+qNN4ohW2g+vQv2t2+rBLoTRJS3KYET1p65LxJKOHpA=";
    };
    nodejs = prev.nodejs_24;
    npmConfigHook = prev.importNpmLock.npmConfigHook;
    npmDeps = prev.importNpmLock {
      npmRoot = src;
    };
    # upstream の prepare/prepack 等を install/pack 時に再実行させない
    npmInstallFlags = [ "--ignore-scripts" ];
    npmPackFlags = [ "--ignore-scripts" ];
    meta = {
      mainProgram = "aicommits";
      description = "A CLI that writes git commit messages with AI";
      homepage = "https://github.com/Nutlope/aicommits";
      license = prev.lib.licenses.mit;
    };
  };
}
