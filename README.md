<div align="center">
  <img
    alt="header"
    src="https://capsule-render.vercel.app/api?type=soft&height=300&color=0:7EBAE4,100:5277C3&text=~/.dotfiles%20with%20nix%20and%20chezmoi&fontColor=e8effc&fontSize=36&desc=for%20macOS&fontAlignY=48&descAlignY=66&textBg=false&descSize=26"
  />
</div>

---

<div align="center">
  <img alt="nix" src="https://img.shields.io/badge/nix-5277C3?style=for-the-badge&logo=nixos&logoColor=white"/>  
  <img alt="macOS" src="https://img.shields.io/badge/macOS-222222?style=for-the-badge&logo=apple&logoColor=white"/>  
  <img alt="技術者倫理 遵守済み" src="https://img.shields.io/badge/%E6%8A%80%E8%A1%93%E8%80%85%E5%80%AB%E7%90%86-%E9%81%B5%E5%AE%88%E6%B8%88%E3%81%BF-0a0a0a?style=for-the-badge&labelColor=ffffff"/>  
</div>

## 設定
1. ホスト名の設定と`CLT`のインストールから`ssh`のキー生成もしくは復元  
```sh
# 設定と確認
sudo scutil --set LocalHostName <hostKey>
sudo scutil --set ComputerName <hostKey>
sudo scutil --set HostName <hostKey>

scutil --get LocalHostName

# インストールと確認
xcode-select --install
xcode-select -p
```
> [!IMPORTANT]
> `hostKey`は`nix/hosts/darwin/<hostKey>`のフォルダ名と一致させる  

2. `Nix`を未インストールの場合は [Determinate](https://docs.determinate.systems) からインストールして確認  
```sh
❯ nix --version
nix (Determinate Nix 3.15.1) 2.33.0
```

3. `chezmoi`の初期化をしてドットファイルの展開  
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply <repository-url>
```

4. セットアップ  
```sh
cd ~/.local/share/chezmoi/scripts
# 確認
./setup.sh --dry-run
# 実行
./setup.sh
```
``` sh
# pre-commit 
pre-commit install
pre-commit install --hook-type pre-push
pre-commit run --all-files
```

## 自動更新  
ワークフローで月曜日/水曜日/金曜日の JST AM 04:00前後に全てのinputを更新して`nix flake check`, `nix build`の確認を行い、エラーがなければ`flake.lock`を更新してPRを作成するので、マージ後にローカルにで取り込んで更新する  
``` sh
cd ~/.local/share/chezmoi/nix
git pull --ff-only
```
``` sh
just check
just check-build
just switch
```

## 手動更新  
各 `input` に対する確認と更新のコマンドは下記  
| 対象 | 確認 | 更新 |
| :--- | :--- | :--- |
| `nixpkgs`      | `just check-update-pkg` | `just update-pkg` |
| `home-manager` | `just check-update-all` | `just update-all` |
| `nix-homebrew` | 〃 | 〃 |
| `darwin`       | 〃 | 〃 |
| `wezterm`      | 〃 | 〃 |
| `nixvim`       | 〃 | 〃 |

### `flake.lcok` の更新を実行
``` sh
# nixpkgs のみ
just check-update-pkg
just update-pkg

# nixpkgs を含むそれ以外も全て
just check-update-all
just update-all
```

### `flake.lcok` 更新後の検証と反映

| 内容 | コマンド |
| :--- | :--- |
| 評価と検証  | `just check`       |
| ビルドを検証 | `just check-build` |
| ビルドと反映 | `just switch`      |

``` sh
# チェックとビルド・切り替え
just check
just check-build
just switch
```

``` sh
# 問題あった場合は restore
git restore flake.lock
# ビルド後であれば restore 後に再ビルド・切り替え
just build
just switch

# 問題なければ
git add .
git commit -m "update flake inputs"
```

### Determinate Nix の更新
現在のバージョンと更新情報を確認して、更新があれば実行

1. バージョンを確認
``` sh
❯ nix --version
nix (Determinate Nix 3.15.1) 2.33.0
```

2. 更新を確認
``` sh
❯ determinate-nixd version
Determinate Nixd daemon version: 3.15.1
Determinate Nixd client version: 3.15.1
Latest version: 3.17.1

A new version of Determinate Nix is available. Please update Determinate Nix using the command line:

    sudo determinate-nixd upgrade

Or re-run the Determinate package from https://dtr.mn/determinate-nix
For more information, see: https://dtr.mn/update
```

3. 更新を実行
``` sh
❯ sudo determinate-nixd upgrade
Upgrading Determinate Nixd... 
Upgrading Determinate Nix... 
Upgrading Nix to "/nix/store/rhxidj1q2l9y3v4ssn691l7f69gpayfg-determinate-nix-3.17.1" 
Restarting Determinate Nixd...
```

4. チェックとビルド・切り替え
```sh
just check
just check-build
just switch
```
``` sh
nix flake check /Users/shouta/.local/share/chezmoi/nix 
✅ formatter.aarch64-darwin (build skipped) 
✅ darwinConfigurations.A3112 (build skipped)
```

5. 反映を確認
``` sh
❯ nix --version
nix (Determinate Nix 3.17.1) 2.33.3
```

``` sh
❯ determinate-nixd version
Determinate Nixd daemon version: 3.17.1 
Determinate Nixd client version: 3.17.1 
You are running the latest version of Determinate Nix. 
```

``` sh
git tag -a snapshot-yyyy.mm.dd-1 -m "Update determinate"
git push origin --tags
```

> [!IMPORTANT]
> Determinateを更新後は`.github/workflows/nix-check.yml`の`[determinate-nix-action](https://github.com/DeterminateSystems/determinate-nix-action)`のバージョンのハッシュ値を確認して合わせる  

## ロールバック  
更新で問題があった場合以下のコマンドで前世代に戻す  
``` sh
sudo /run/current-system/sw/bin/darwin-rebuild --rollback
```

世代の一覧は下記で確認  
``` sh
sudo /run/current-system/sw/bin/darwin-rebuild --list-generations

# 出力例
48   2026-02-11 15:53:15
49   2026-02-11 16:07:22
50   2026-02-11 16:08:22
51   2026-02-11 16:21:58
52   2026-02-11 18:03:24   (current)
```

> [!IMPORTANT]
> シェルの起動にも問題がある場合、標準の `Terminal.app` を開いて、上部メニューから「Shell > New Command」を選択して`/bin/bash --noprofile --norc`を入力すると`bash`で起動する  

> [!IMPORTANT]
> `Run inside shell`は無効にする
