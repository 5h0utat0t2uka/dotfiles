{ buildNpmPackage, lib, fetchurl, makeWrapper, nodejs, jq }:

buildNpmPackage rec {
  pname = "vscode-langservers-extracted";
  version = "4.10.0";
  src = fetchurl {
    url = "https://registry.npmjs.org/vscode-langservers-extracted/-/vscode-langservers-extracted-${version}.tgz";
    hash = "sha256-1uLQkNCcS5Hap06edGKj0/JE77lqpREQBM//pJ1tye8=";
  };
  sourceRoot = "package";
  postPatch = ''
    ${lib.getExe jq} --from-file ${./package-json.jq} package.json > package.json.tmp
    mv package.json.tmp package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-8yAHUf5R9LwPDUHRxPzShmLazRFL0EIAtKKgV0yiKGU=";
  dontNpmBuild = true;
  npmFlags = [ "--loglevel=error" ];
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    pkgdir="$out/lib/node_modules/vscode-langservers-extracted"
    mkdir -p "$pkgdir" "$out/bin"
    cp -R package.json README.md LICENSE lib bin node_modules "$pkgdir"
    for exe in \
      vscode-css-language-server \
      vscode-eslint-language-server \
      vscode-html-language-server \
      vscode-json-language-server \
      vscode-markdown-language-server
    do
      makeWrapper ${nodejs}/bin/node "$out/bin/$exe" \
        --add-flags "$pkgdir/bin/$exe"
    done
    runHook postInstall
  '';
  meta = {
    description = "HTML/CSS/JSON/ESLint/Markdown language servers extracted from VS Code";
    homepage = "https://github.com/hrsh7th/vscode-langservers-extracted";
    license = lib.licenses.mit;
    mainProgram = "vscode-html-language-server";
  };
}
