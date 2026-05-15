{ ... }:

final: prev: {
  aicommits = prev.buildNpmPackage rec {
    pname = "aicommits";
    version = "3.2.0";
    src = prev.fetchFromGitHub {
      owner = "Nutlope";
      repo = "aicommits";
      rev = "v${version}";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    npmConfigHook = prev.importNpmLock.npmConfigHook;
    npmDeps = prev.importNpmLock {
      npmRoot = src;
    };
    meta = {
      mainProgram = "aicommits";
      description = "A CLI that writes git commit messages with AI";
      homepage = "https://github.com/Nutlope/aicommits";
      license = prev.lib.licenses.mit;
    };
  };
}
