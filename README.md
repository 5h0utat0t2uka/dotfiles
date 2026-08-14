<img alt="nix-check" src="https://img.shields.io/github/actions/workflow/status/5h0utat0t2uka/dotfiles/nix-check.yml?branch=main&style=for-the-badge&label=nix-check"/> <img alt="技術者倫理 遵守済み" src="https://img.shields.io/badge/%E6%8A%80%E8%A1%93%E8%80%85%E5%80%AB%E7%90%86-%E9%81%B5%E5%AE%88%E6%B8%88%E3%81%BF-0a0a0a?style=for-the-badge&labelColor=ffffff"/>

<!--<div align="center">
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
</div>-->

## 設定
1. ホスト名の設定と`CLT`のインストールから`ssh`のキーペア生成  
```sh
# ホスト名設定と確認
sudo scutil --set LocalHostName <hostKey>
sudo scutil --set ComputerName <hostKey>
sudo scutil --set HostName <hostKey>
scutil --get LocalHostName

# CLTインストールと確認
xcode-select --install
xcode-select -p
```
> [!IMPORTANT]
> `hostKey`は`nix/hosts/darwin/<hostKey>`のフォルダ名と一致させる  

2. [Determinate Nix](https://docs.determinate.systems) からインストールして確認  
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
pre-commit install --hook-type pre-commit
```

## 自動更新  
[GitHub Actions](https://github.com/5h0utat0t2uka/dotfiles/blob/main/.github/workflows/nix-update-check.yml) で全てのinputを更新して `nix flake check`, `nix build` の確認を行い、エラーがなければ `flake.lock` を更新してPRを作成するので、マージ後にローカルにで取り込んで更新する  
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
| `nixvim`       | 〃 | 〃 |

### `flake.lcok` 更新後の検証と反映  
``` sh
# 評価と検証
just check
# ビルドを検証
just check-build
# ビルドと反映
just switch
```

``` sh
# 問題あった場合は restore
git restore flake.lock
# ビルド後であれば restore 後に再ビルド・切り替え
just check-build
just switch

# 問題なければ
pre-commit run --all-files --show-diff-on-failure
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

## 署名
Secure Enclave を利用した Git の署名設定  

1. 新しい Mac に既存の Secure Enclave 鍵がないことを確認する  
``` sh
sc_auth list-ctk-identities -t ssh
```

2. 新しい Git 署名鍵を Secure Enclave に生成する  
``` sh
sc_auth create-ctk-identity \
  -l git-sign \
  -k p-256-ne \
  -t none
```

> [!NOTE]
> Touch ID を必須にしたい場合は `-t bio` にする

3. OpenSSH 用の key handle を取り出す  
一時ディレクトリで実行
``` sh
tmpdir="$(mktemp -d)"
cd "$tmpdir"

/usr/bin/ssh-keygen \
  -w /usr/lib/ssh-keychain.dylib \
  -K \
  -N ""
```

以下は空のまま Enter
``` text
Enter PIN for authenticator:
```

5. Git 署名用の名前で配置する  
``` sh
mkdir -p ~/.ssh

install -m 600 \
  id_ecdsa_sk_rk \
  ~/.ssh/id_git_sign

install -m 644 \
  id_ecdsa_sk_rk.pub \
  ~/.ssh/id_git_sign.pub
```

``` sh
/usr/bin/ssh-keygen -lf ~/.ssh/id_git_sign.pub
```

``` sh
cd
rm -rf "$tmpdir"
```

6. GitHub に新しい公開鍵を Signing Key として追加する
GitHub の「Settings」から SSH and GPG keys > New SSH key で以下の内容を「Signing Key」として登録
``` sh
pbcopy < ~/.ssh/id_git_sign.pub
```

7. dotfiles の `allowed_signers` を更新する  
現在の署名に追記する
```text
nix/modules/home-manager/git/allowed_signers
```

``` text
<email> namespaces="git" OLD_PUBLIC_KEY
<email> namespaces="git" NEW_PUBLIC_KEY
```

旧署名を残す事で、過去の commit もローカルで検証可能
```text
過去の commit
└─ OLD key → ローカルで検証可能

移行後の commit
└─ NEW key → ローカルで検証可能
```

8. dotfiles に変更を追加して Nix を反映する
``` sh
git add nix/modules/home-manager/git/allowed_signers
```
``` sh
just check
just check-build
just switch
```

反映後、設定内容の確認
``` sh
git config --global --get user.signingKey
git config --global --get gpg.format
git config --global --get gpg.ssh.program
git config --global --get commit.gpgSign
git config --global --get tag.gpgSign
git config --global --get gpg.ssh.allowedSignersFile
```
