この更新が必要なのは以下のケース

| 条件 | 理由 |
|:---|:---|
| `vscode-langservers-extracted`のバージョン更新 | tarball が変わるので依存ツリーが変わる。`src.hash` も再取得が必要 |
| `package-json.jq` の更新 | `vscode-markdown-languageservice` のピン変更、他の依存の上書き追加など、`package.json` を変えれば lock も変わる |
| 依存に脆弱性が発生した場合 | `npm install --package-lock-only vscode-uri@x.y.z` 等で該当依存を上げる必要がある |


## 更新方法  
1. `nix/pkgs/vscode-langservers-extracted-npm/default.nix`, `nix/pkgs/vscode-langservers-extracted-npm/package-json.jq` を編集

2. lockfile 再生成
``` sh
cd "$(mktemp -d)"
nix shell nixpkgs#nodejs nixpkgs#jq
curl -LO https://registry.npmjs.org/vscode-langservers-extracted/-/vscode-langservers-extracted-4.10.0.tgz
tar xzf vscode-langservers-extracted-4.10.0.tgz

cd package
jq --from-file ~/.local/share/chezmoi/nix/pkgs/vscode-langservers-extracted-npm/package-json.jq \
  package.json > p.json && mv p.json package.json

npm install --package-lock-only
npm ci --loglevel=error && npm audit
```

3. コピー
``` sh
cp package-lock.json ~/.local/share/chezmoi/nix/pkgs/vscode-langservers-extracted-npm/
exit
```

4. ハッシュを取り直す
`nix/pkgs/vscode-langservers-extracted-npm/default.nix`の`src.hash`, `npmDepsHash`に`lib.fakeHash`を入れる
``` sh
cd ~/.local/share/chezmoi
git add -A && git commit -m "wip"
nix build .#vscode-langservers-extracted
```

5. スモークテスト
``` sh
git add -A && git commit -m "wip"
just check
just check-build
just switch
```
