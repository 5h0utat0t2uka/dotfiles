{ ... }:

final: prev: {
  aicommits = prev.buildNpmPackage rec {
    pname = "aicommits";
    version = "3.4.0";
    src = prev.fetchFromGitHub {
      owner = "Nutlope";
      repo = "aicommits";
      rev = "v${version}";
      hash = "sha256-xh7TM3ThajeOXYCj2Vc246u3kYxA1VCHFWM4QbM8DGo=";
    };

    nodejs = prev.nodejs_24;
    npmInstallFlags = [ "--ignore-scripts" ];
    npmPackFlags = [ "--ignore-scripts" ];
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
