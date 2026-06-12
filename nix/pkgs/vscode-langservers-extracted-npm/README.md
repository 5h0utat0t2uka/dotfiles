# 更新方法  

例えば `4.10.0` から `4.11.0` にする場合:  
``` sh
cd ~/.local/share/chezmoi/nix/pkgs/vscode-langservers-extracted-npm
```

1. 一時的にダウンロードして展開する
``` sh
mkdir -p temp
cd temp
npm pack vscode-langservers-extracted@4.11.0
tar -xzf vscode-langservers-extracted-4.11.0.tgz
cd package
```

2. 新しいバージョンに対応する `package-lock.json` を生成する
``` sh
# runtime deps の lockfile を生成
npm install --package-lock-only --omit=dev
```

3. 生成された `package-lock.json` をコピーする
``` sh
cp package-lock.json ~/.local/share/chezmoi/nix/pkgs/vscode-langservers-extracted-npm/package-lock.json
```

4. (1) で作成した一時ディレクトリを削除する
``` sh
cd ../../
rm -rf temp
```

5. `~/.local/share/chezmoi/nix/pkgs/vscode-langservers-extracted-npm/default.nix` の `version` と `hash`, `npmDepsHash` を更新する
``` nix
{ buildNpmPackage, lib, fetchurl, makeWrapper, nodejs }:

buildNpmPackage rec {
  pname = "vscode-langservers-extracted";
  version = "4.11.0";
  src = fetchurl {
    url = "https://registry.npmjs.org/vscode-langservers-extracted/-/vscode-langservers-extracted-${version}.tgz";
    hash = lib.fakeHash
  };
  sourceRoot = "package";
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';
  dontNpmBuild = true;
  npmDepsHash = lib.fakeHash
  npmRoot = ".";
  npmFlags = [
    "--omit=dev"
    "--loglevel=error"
  ];
  nativeBuildInputs = [
    makeWrapper
  ];

  ...

```
