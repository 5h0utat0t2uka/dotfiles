# 新しいMacのセットアップ

対象はApple SiliconのmacOS。`scripts/setup.sh` はmacOS標準の `/bin/bash` で動作し、Nix提供のzshとHome Managerの設定はビルド・適用の過程で導入する。

## 1. 移行前の準備
- 新Macのユーザー名・LocalHostNameに対応する `nix/hosts/darwin/<host>/identity.nix` と `default.nix` を用意する。現在のホストは `A3112`。別ホストは既存構成を参考に追加し、ユーザー名・homeDirectory・flakeRootも確認してコミットする。
- iCloud上の `chezmoi-age-key.txt.age` と `sops-age-key.txt.age`、それぞれ異なる復旧パスフレーズを用意する。パスフレーズは、復旧前のpass/passageやiCloudだけに依存させない。
- 旧Macから必要なデータをバックアップする。このスクリプトは個人データ・pass/passageのストア・YubiKey本体を復旧しない。

## 2. 新Macで手動導入
macOSのデスクトップへ通常ユーザーでログインし、Terminal.appで操作する。SOPSの適用にはそのユーザーのGUIセッションが必要。
Command Line Toolsをインストールし、ダイアログで完了するまで待つ。フルXcodeを使用する場合も、有効な開発ツールを選択しておく。

```sh
xcode-select --install
xcode-select -p
xcrun --find clang
```

[Determinate Nixの公式サイト](https://docs.determinate.systems/)からmacOS用pkgをインストールする。ターミナルを開き直して確認する。

```sh
nix --version
```

公開リポジトリをHTTPSで取得する。chezmoiの事前インストールは不要。

```sh
git clone https://github.com/5h0utat0t2uka/dotfiles.git "$HOME/.local/share/chezmoi"
cd "$HOME/.local/share/chezmoi"
```

LocalHostNameを対応するホストディレクトリ名に合わせる。次は既存の `A3112` を復旧する例。新ホストではそのホスト名に置き換える。

```sh
sudo scutil --set LocalHostName A3112
scutil --get LocalHostName
```

`identity.nix` のユーザー名・ホームディレクトリ・アーキテクチャも一致する必要がある。スクリプトはホストやアカウントを自動生成・改名しない。

## 3. iCloudのバックアップをダウンロード
Finderで次のファイルをローカルにダウンロードする。iCloudへのサインインや同期はスクリプトの対象外。`--check` のファイル存在確認だけではダウンロード完了や復号成功は保証しない。

```text
~/Library/Mobile Documents/com~apple~CloudDocs/share/
├── chezmoi/chezmoi-age-key.txt.age
└── sops/sops-age-key.txt.age
```

別の場所に保存していても、以下の引数で絶対パスを指定できる。ファイルやパスフレーズはリポジトリへ追加しない。

## 4. 確認と適用
```sh
./scripts/setup.sh --check \
  --chezmoi-backup "$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/chezmoi/chezmoi-age-key.txt.age" \
  --sops-backup "$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/sops/sops-age-key.txt.age"
```

`--check` はローカルの前提条件だけを確認する。Nix評価・ダウンロード・復号・ファイルの作成/移動・sudoは行わない。引数なしでも同じ動作。鍵の内容、Nixの評価、`/etc` の衝突、ビルドは次の `--apply` で検証する。

```sh
./scripts/setup.sh --apply \
  --chezmoi-backup "$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/chezmoi/chezmoi-age-key.txt.age" \
  --sops-backup "$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/sops/sops-age-key.txt.age"
```

`--apply` はクリーンなコミット済みcheckoutを要求する。実行中に別のターミナルからリポジトリを更新しない。出力をログへリダイレクトせず、対話端末で実行する。

順に実行される処理:  
1. `flake.lock` のnixpkgsからchezmoi・age・SOPS・jq・coreutilsを準備する。coreutilsは既存ファイルを置換しない原子的な配置に使用する。
2. ホストの実設定、chezmoiテンプレート、`/etc` の既存ファイルを検証する。
3. 不足するage identityを対話的に復旧し、recipientを確認する。既存の正しいidentityはそのまま使う。
4. chezmoi暗号化ファイルとSOPS秘密情報が復号できることを確認する。平文は表示・保存しない。
5. ロック済みNix構成を評価・ビルドする。
6. chezmoiの設定を初期化し、変更対象のパスを表示して適用する。競合はchezmoiのプロンプトで判断する。`diff` を選ぶと秘密ファイルの本文が表示され得るので注意する。
7. ビルドしたシステム内の `darwin-rebuild` からsudoで適用する。初回もロック済みnix-darwinを使う。
8. 適用済みシステム・ツール・chezmoiの状態・SOPS生成物を確認し、pre-commit hookを導入する。

identityは `0600`、復旧先ディレクトリは `0700` で作成する。recipientは `.chezmoi.toml.tmpl` と `.sops.yaml` の公開値を使う。現在は用途ごとに1つのネイティブage identityを使用する構成に対応する。

既存のidentityがある場合、バックアップ引数は不要。間違った鍵・シンボリックリンク・安全でない権限は停止理由になる。パスフレーズは引数や環境変数へ渡さず、ageのプロンプトに入力する。

### 適用される既存の方針
- Homebrewの `autoUpdate = true`、`upgrade = true`、`cleanup = "zap"` は現在のNix設定をそのまま適用する。既存環境では管理対象アプリの更新に加えて、宣言されていないHomebrewパッケージや関連データの削除が起こり得る。初期構築だけの無害な再確認コマンドではない。
- Nixの入力は更新しない。ただしHomebrewや配布元のアプリまで完全に同一バージョンへ固定するものではない。
- Home Managerのzsh設定を維持する。既存ユーザーのログインシェルはnix-darwinの `users.knownUsers` 管理対象かどうかでも挙動が変わる。スクリプトは `chsh` を実行せず、不一致なら設定されたzshへ変更するコマンドを表示する。必要なら適用完了後に実行し、新しいターミナルで確認する。
- `~/.local/bin/chezmoi` が既にある場合は残る。通常運用ではHome Managerでもchezmoiを導入する。

## 5. 失敗・中断した場合
エラーには失敗した段階が表示される。失敗原因を解消し、同じコマンドを再実行する。セットアップ全体はトランザクションではなく、既に復旧したidentityや適用済み設定は残る。自動ロールバックはしない。
- `/etc` の衝突: 表示された対象を確認して手動でバックアップする。スクリプトは既存設定を自動移動しない。通常のmacOSファイルはnix-darwinが持つ許可ハッシュで判定する。
- chezmoi設定の不一致: 現在の `chezmoi.toml` とテンプレートの差を確認し、必要なら手動で `chezmoi init` を実行する。既存設定を黙って上書きしない。
- SOPS生成物の確認失敗: `~/Library/Logs/SopsNix` をローカルで確認する。ログや秘密情報を公開しない。
- 強制終了後のロック: 実行中のsetupプロセスがないことを確認して、空の `.git/dotfiles-setup.lock` を `rmdir` で削除する。通常の終了・エラー・INT/TERMでは自動解除される。
- SIGKILLや電源断では一時データの削除処理が実行されない。identityディレクトリの `.setup-age.*`・`.setup-config.*` とOS一時ディレクトリの `dotfiles-setup.*` をローカルで確認する。削除はSSD上の完全消去を保証しない。

pass/password-store・passageの復旧とYubiKeyの署名・認証確認は別の工程。`restore-pass.sh` はこの変更には含まない。

## 検証
`scripts/tests/setup-test.sh` は実際の秘密鍵やmacOS設定を使わず、一時データで復旧・失敗時の動作を検証する。macOSの `/bin/bash` と、flakeで固定したbootstrap-toolsが必要。

```sh
nix build --no-update-lock-file --no-link --print-out-paths ./nix#bootstrap-tools
# 上の出力パスを渡す
/bin/bash scripts/tests/setup-test.sh /nix/store/…-dotfiles-bootstrap-tools
```

新Macでのsudo適用、Homebrewインストール、GUI認証までをこのテストが保証するわけではない。

## Ref
- [Apple: Command Line Tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools)
- [Determinate Nix](https://docs.determinate.systems/determinate-nix/)
- [chezmoi init](https://www.chezmoi.io/reference/commands/init/)、[apply](https://www.chezmoi.io/reference/commands/apply/)、[status](https://www.chezmoi.io/reference/commands/status/)
- [Nix build](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-build)
- [nix-darwinの起動処理](https://github.com/nix-darwin/nix-darwin/blob/master/pkgs/nix-tools/darwin-rebuild.sh)、[/etcの衝突検査](https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/etc.nix)
- [sops-nix Home Manager実装](https://github.com/Mic92/sops-nix/blob/master/modules/home-manager/sops.nix)
