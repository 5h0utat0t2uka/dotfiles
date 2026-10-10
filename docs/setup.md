# Macの復旧手順
対象はApple SiliconのmacOS。新Macのデスクトップへ通常ユーザーでログインし、Terminal.appで実行する。  

## 1. 事前準備
- 新Macのユーザー名・ホスト名に対応する `nix/hosts/darwin/<host>/identity.nix` と `default.nix` を用意し、コミットしておく。
- chezmoi用・SOPS用の暗号化済みage identityと、それぞれの復旧パスフレーズを用意する。パスフレーズは復旧前のpassやiCloudだけに依存させない。
- 個人データをバックアップする。この手順では個人データ・password-store・YubiKey本体は復旧しない。

## 2. Command Line ToolsとDeterminate Nixを導入する
[Command Line Tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools)をインストールし、完了後に確認する。
```sh
xcode-select --install
```
```sh
xcode-select -p
xcrun --find clang
```

[Determinate Nix公式サイト](https://docs.determinate.systems/determinate-nix/)からmacOS用pkgをインストールしてターミナルを開き直して確認する。
```sh
nix --version
```

## 3. ホスト名を設定し、dotfilesを取得する
以下は `A3112` の例。M1の `A2338` を復旧する場合は読み替える。新しいホストは手順1で用意した名前を使う。
```sh
scutil --get LocalHostName
scutil --get ComputerName
sudo scutil --set LocalHostName A3112
sudo scutil --set ComputerName A3112
```

初回のみ、次の場所へcloneする。取得済みならcloneせず、そのディレクトリへ移動する。chezmoiの事前インストールは不要。
```sh
git clone https://github.com/5h0utat0t2uka/dotfiles.git "$HOME/.local/share/chezmoi"
cd "$HOME/.local/share/chezmoi"
```

`--apply` は未コミット・未追跡の変更があると停止する。復旧するコミットを確認し、実行中はリポジトリを更新しない。

## 4. iCloudからバックアップをダウンロードする
Finderで、次のファイルをローカルへダウンロードする。
```text
~/Library/Mobile Documents/com~apple~CloudDocs/share/
├── chezmoi/chezmoi-age-key.txt.age
└── sops/sops-age-key.txt.age
```

## 5. 確認して適用する
```sh
./scripts/setup.sh --check \
  --chezmoi-backup "$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/chezmoi/chezmoi-age-key.txt.age" \
  --sops-backup "$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/sops/sops-age-key.txt.age"
```

`Local checks passed.` が表示されたら次へ進む。`--check` は前提条件の確認のみで、復号・ビルドはまだ行わない。
```sh
./scripts/setup.sh --apply \
  --chezmoi-backup "$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/chezmoi/chezmoi-age-key.txt.age" \
  --sops-backup "$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/sops/sops-age-key.txt.age"
```

- ageのプロンプトには、表示された用途のバックアップ用パスフレーズを入力する。引数・環境変数に書かず、実行ログも保存しない。
- 既存の正しいidentityは再利用される。chezmoiの競合は内容を確認して判断する。`diff` には秘密情報が表示され得る。
- SSH設定・SSH鍵ファイルもchezmoiで復元する。YubiKeyの設定変更・接続確認は行わない。
- Homebrewの更新と `cleanup = "zap"` が適用される。既存環境では、管理外パッケージや関連データの削除が起こり得る。

## 6. 完了を確認する
`Setup completed. Open a new terminal.` が表示されたら完了。  
ここで再起動を行い、一度`karabiner-elements`を起動してキーボード関連の設定を確認する。

ショートカットからシェルを実行する場合は、ショートカットアプリの「設定 → 詳細 → スクリプトの実行を許可」を有効にする。

<a id="pass-recovery"></a>

続いて [pass/password-storeの復旧手順](restore-pass.md)で`pass`の復号とGitHubへのSSH読み取りアクセスを確認する。

## 失敗・中断した場合
- エラーの段階と原因を確認し、解消してから同じコマンドを再実行する。復旧済みidentityや適用済み設定は残り、自動では巻き戻らない。
- `/etc` やchezmoiの競合は、対象を確認してバックアップする。無条件に削除・上書きしない。
- SOPS関連は表示された入力パスと `~/Library/Logs/SopsNix` をローカルで確認する。秘密情報を含むログを公開しない。
- 強制終了後は、実行中でないことを確認してからロック `.git/dotfiles-setup.lock` と残存一時ファイルを点検する。対象不明のまま削除しない。

<a id="emergency-pass-recovery"></a>

## YubiKeyをすべて失った場合
`restore-pass.sh` の対象外。password-storeのバックアップbundle内にある `.github/README.md` の「B. YubiKeyをすべて失った場合」「software recovery 後に PIV-only へ戻す」を参照する。
software秘密鍵の復元は専用の隔離したGPG環境で行い、通常の `~/.gnupg` への取り込みやYubiKeyの初期化は、この通常移行の手順では行わない。
