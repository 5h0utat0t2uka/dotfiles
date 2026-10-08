# 新しいMacのセットアップ

対象はApple SiliconのmacOS。`scripts/setup.sh` はmacOS標準の `/bin/bash` で動作し、Nix提供のzshとHome Managerの設定はビルド・適用の過程で導入する。

## 1. 移行前の準備
- 新Macのユーザー名・LocalHostNameに対応する `nix/hosts/darwin/<host>/identity.nix` と `default.nix` を用意する。
- iCloud上の `chezmoi-age-key.txt.age` と `sops-age-key.txt.age`、それぞれ異なる復旧パスフレーズを用意する。パスフレーズは、復旧前のpassやiCloudだけに依存させない。
- 旧Macから必要なデータをバックアップする。このスクリプトは個人データ・password-store・YubiKey本体を復旧しない。passのバックアップと復旧は[後述の手順](#pass-recovery)を参照する。

## 2. 新Macで手動導入
macOSのデスクトップへ通常ユーザーでログインし、デフォルトのTerminal.appで操作する。  
LocalHostNameを対応するホストディレクトリ名に合わせる。  
次は既存の `A3112` を復旧する例で、新ホストではそのホスト名に置き換える。
```sh
# LocalHostName, ComputerNameの確認と設定
scutil --get LocalHostName
scutil --get ComputerName
sudo scutil --set LocalHostName A3112
sudo scutil --set ComputerName A3112
```

Command Line Toolsをインストールし、ダイアログで完了するまで待つ。
```sh
xcode-select --install
xcode-select -p
xcrun --find clang
```

[Determinate Nixの公式サイト](https://docs.determinate.systems/)からmacOS用pkgをインストールする。ターミナルを開き直して確認する。
```sh
nix --version
```

`dotfiles`リポジトリをHTTPSで取得する。chezmoiの事前インストールは不要。
```sh
git clone https://github.com/5h0utat0t2uka/dotfiles.git "$HOME/.local/share/chezmoi"
cd "$HOME/.local/share/chezmoi"
```

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
6. chezmoiの設定を初期化し、変更対象のパスを表示して適用する。初期化記録・適用履歴は通常利用するchezmoiと共有し、終了後も残す。事前検証だけは一時的な管理状態に隔離する。競合はchezmoiのプロンプトで判断する。`diff` を選ぶと秘密ファイルの本文が表示され得るので注意する。
7. ビルドしたシステム内の `darwin-rebuild` からsudoで適用する。初回もロック済みnix-darwinを使う。
8. 適用済みシステム・ツール・chezmoiの状態・SOPS生成物を確認し、pre-commit hookを導入する。

identityは `0600`、復旧先ディレクトリは `0700` で作成する。recipientは `.chezmoi.toml.tmpl` と `.sops.yaml` の公開値を使う。現在は用途ごとに1つのネイティブage identityを使用する構成に対応する。

既存のidentityがある場合、バックアップ引数は不要。間違った鍵・シンボリックリンク・安全でない権限は停止理由になる。パスフレーズは引数や環境変数へ渡さず、ageのプロンプトに入力する。

### SSH設定とYubiKey用鍵ファイル
コミット済みの `private_dot_ssh/encrypted_private_config.age` と暗号化済みのSSH鍵ファイルも、上記の復号検証・`chezmoi apply` の対象に含まれる。  
新Macでは `~/.ssh/config` と鍵ファイルが `0600`、`~/.ssh` が `0700` で復元される。

これはリポジトリで管理するファイルの復元であり、YubiKey本体の設定やGitHub/VPSへの公開鍵登録、実際の接続確認は含まない。`Include`で参照する別ファイルも、自動で収集・復元されるわけではない。設定に含まれる端末固有のパスは移行前に確認する。

### 適用される既存の方針
- Homebrewの `autoUpdate = true`、`upgrade = true`、`cleanup = "zap"` は現在のNix設定をそのまま適用する。既存環境では管理対象アプリの更新に加えて、宣言されていないHomebrewパッケージや関連データの削除が起こり得る。初期構築だけの無害な再確認コマンドではない。
- Nixの入力は更新しない。ただしHomebrewや配布元のアプリまで完全に同一バージョンへ固定するものではない。
- Home Managerのzsh設定を維持する。既存ユーザーのログインシェルはnix-darwinの `users.knownUsers` 管理対象かどうかでも挙動が変わる。スクリプトは `chsh` を実行せず、不一致なら設定されたzshへ変更するコマンドを表示する。必要なら適用完了後に実行し、新しいターミナルで確認する。
- `~/.local/bin/chezmoi` が既にある場合は残る。通常運用ではHome Managerでもchezmoiを導入する。

## 5. 失敗・中断した場合
エラーには失敗した段階が表示される。失敗原因を解消し、同じコマンドを再実行する。セットアップ全体はトランザクションではなく、既に復旧したidentityや適用済み設定は残る。自動ロールバックはしない。
- `/etc` の衝突: 表示された対象を確認して手動でバックアップする。スクリプトは既存設定を自動移動しない。通常のmacOSファイルはnix-darwinが持つ許可ハッシュで判定する。
- chezmoi設定の不一致: 現在の `chezmoi.toml` とテンプレートの差を確認し、必要なら手動で `chezmoi init` を実行する。既存設定を黙って上書きしない。
- SOPS入力ファイルの確認失敗: `SOPS input is missing...` は鍵ではなく、表示された暗号化ファイルの参照先の問題。通常の復号失敗とは分けて表示する。復号失敗時もファイルパスと終了コードのみ表示し、入力内容を含み得る生のエラー出力は表示しない。
- SOPS生成物の確認失敗: `~/Library/Logs/SopsNix` をローカルで確認する。ログや秘密情報を公開しない。
- 強制終了後のロック: 実行中のsetupプロセスがないことを確認して、空の `.git/dotfiles-setup.lock` を `rmdir` で削除する。通常の終了・エラー・INT/TERMでは自動解除される。
- SIGKILLや電源断では一時データの削除処理が実行されない。identityディレクトリの `.setup-age.*`・`.setup-config.*` とOS一時ディレクトリの `dotfiles-setup.*` をローカルで確認する。削除はSSD上の完全消去を保証しない。

> [!NOTE]  
> ショートカットアプリで下記の設定を行い実行権限をつける  
> 「設定」->「詳細」->「スクリプトの実行を許可」  

<a id="pass-recovery"></a>

## 6. pass/password-storeの復旧・移行
`setup.sh --apply` の成功後、新Macで `scripts/restore-pass.sh` を別途実行する。setup.shから自動実行はしない。対象は既存YubiKeyを使う通常移行のみ。passageは対象外とし、YubiKey本体の設定・鍵・PINや別スロットは変更しない。

現在のpassは、OpenPGPのP-256暗号化副鍵に対応する秘密鍵をYubiKeyの **PIV 9D** で使う。Macには公開鍵と、YubiKeyを参照するshadow keyを配置する。YubiKeyのOpenPGPアプリへ鍵を移す手順ではない。

- Nixが導入するもの: GnuPG、pass/pass-otp、pinentry-mac、yubikey-manager、および `application-priority piv` / `use-keyboxd` の設定。
- この工程で復元するもの: OpenPGP公開鍵、ownertrust、shadow key、暗号化済みpassword-store。
- 通常移行で復元しないもの: `secret.asc`、PIV用の秘密鍵、失効証明書。YubiKeyの初期化・鍵の書き換え・PIN変更も行わない。

GPG設定は [gnupgモジュール](../nix/modules/home-manager/gnupg/default.nix)、passの導入は [passモジュール](../nix/modules/home-manager/pass/default.nix) で管理する。Home Managerが管理する設定ファイルを手作業で上書きしない。

### 移行前に用意するもの
| 用意するもの | 用途 |
| --- | --- |
| 既存のPrimaryまたはSecondary YubiKeyとPIV PIN | 通常移行での復号 |
| `public.asc` | OpenPGP公開鍵の復元。単独バックアップ、または下記archiveから取得 |
| `password-store-p256-git.bundle` | 最新のコミット済みストアとGit履歴。GitHubから取得する場合は代替可能 |
| `password-store-p256-recovery.tar.age` と復旧パスフレーズ | 公開鍵の取り出し、および全YubiKey喪失時の緊急復旧 |
| 信頼できる別の記録 | 主鍵・P-256副鍵の完全なfingerprint、PIV 9Dのkeygrip、GitHubの取得元URL |

バックアップはFinderでローカルへダウンロードする。現在の保管先は `~/Library/Mobile Documents/com~apple~CloudDocs/share/pass/`。移動している場合は以下の変数を変更する。PINやパスフレーズ、秘密鍵、実際のパスワードをこの公開リポジトリに記載しない。

bundleは未コミットの変更やGitのローカル設定を保存しない。旧Macで最新のコミットをバックアップ済みか確認する。recovery archive内部の `password-store.bundle` は古い補助スナップショットなので、通常は外部の `password-store-p256-git.bundle` を使う。[Git公式: bundleの保存範囲](https://git-scm.com/docs/git-bundle)

以下は新Macの通常の `~/.gnupg` と `~/.password-store` を使う例。`GNUPGHOME` や `PASSWORD_STORE_*` を独自設定している場合は、先に復元先・鍵選択が変わらないか確認する。同じターミナルで順に実行し、各確認に失敗した場合は先へ進まない。旧Macの稼働中ストアでは実行しない。

### スクリプトで復旧する

復旧前の新Macで実行する。既存の `~/.password-store` がある端末では、`--check` / `--apply` ともに停止する。上書き・merge・既存ストアへの再適用のためのスクリプトではない。

次の値は、旧Macや独立したオフライン記録と照合した値に置き換える。fingerprintとkeygripは40桁の16進数で、`!` は付けない。`--test-entry` は既存エントリの相対パス（末尾の `.gpg` なし）。鍵の期待値を公開鍵ファイルから無検証で自動採用しないため、明示指定を必須にしている。

```sh
pass_restore_args=(
  --primary-fingerprint '照合済みの主鍵fingerprint'
  --encryption-fingerprint '照合済みのP-256暗号化副鍵fingerprint'
  --keygrip '照合済みのPIV 9D keygrip'
  --test-entry '復号確認に使う既存エントリ名'
)
./scripts/restore-pass.sh --check "${pass_restore_args[@]}"
```

デフォルトでは前述のiCloudの `share/pass` にある `password-store-p256-git.bundle` と `public.asc` を使う。保存先が違う場合は `--backup-dir /絶対パス`、ファイル単位では `--bundle` / `--public-key` を指定できる。

`--check` はコマンド・パス・権限・引数のみの確認。GPGの起動、鍵の読み込み、YubiKeyへのアクセス、一時ファイルの作成は行わない。バックアップ内容の正しさや復号成功を保証するものではない。

PrimaryかSecondaryを1本だけ接続し、他のGPG操作を止めてから適用する。sudoは不要。対話端末で実行し、セッションをログへ保存しない。

```sh
./scripts/restore-pass.sh --apply "${pass_restore_args[@]}"
```

処理の順序:

1. 完全なGit bundleであることを空のリポジトリで検証し、一時領域へcloneする。Git整合性、symlink/submoduleがないこと、全 `.gpg-id` と指定エントリの存在を確認する。
2. 公開鍵を隔離したGNUPGHOMEで検査する。期待する主鍵・有効なP-256副鍵・keygripを照合し、秘密鍵を含む入力は拒否する。
3. 表示されたコミット・鍵が意図したものであることを確認し、`restore` と入力する。この確認以前には通常のGPG環境もストアも変更しない。
4. 接続したPIV 9Dのkeygripを確認し、不足するPIV 9Dのshadow keyだけを作成する。通常GNUPGHOMEへ公開鍵を取り込み、確認済みの本人の主鍵だけにultimate ownertrustを設定する。異なる信頼設定や対象のsoftware秘密鍵がある場合は停止し、自動削除・上書きしない。
5. 選択した実エントリの復号と使用鍵のfingerprint、`pass show`、ストア外のテスト文字列の暗号化・復号を確認する。実エントリの平文は表示・保存しない。PIN/Touchは通常のプロンプトに応じ、PINを推測して再試行しない。
6. 全検証に成功した場合だけ、新しい `~/.password-store` を権限 `0700` で確保して配置する。既存のストアは変更しない。ストア内エントリの追加・編集、`pass init`、pushは行わない。

全パスワードの復号を網羅する検査ではなく、選択したエントリとテスト文字列の検証である。Secondaryでも別途復号確認する。SSH認証・Git署名の検証はこのスクリプトには含めない。

bundleをcloneした際の `origin` は、そのままだとローカルbundleを指すため除去する。同期先が確認できている場合は `--origin 'git@github.com:OWNER/REPO.git'` を追加すると設定できる。指定してもネットワークへの接続・pushは行わない。

#### public.ascが古い場合

ファイルの更新日だけでは判断しない。`--apply` でP-256副鍵などが一致しなければ、通常のGPG環境へ取り込まずに停止する。2025年時点の公開鍵には、2026年に追加した副鍵が含まれない可能性がある。

その場合は、現在の復旧archiveを取得元として明示指定できる。`--public-key` との併用は不可で、自動フォールバックもしない。

```sh
./scripts/restore-pass.sh --apply "${pass_restore_args[@]}" \
  --recovery-archive "$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/pass/password-store-p256-recovery.tar.age"
```

ageのプロンプトに入力するのはarchive用の復旧パスフレーズ。復号ストリームから `./public.asc` だけをファイルへ取り出し、同じ鍵検証を行う。復号済みtar、`secret.asc`、portable秘密鍵はディスクに展開せず、通常GNUPGHOMEへも取り込まない。

#### 中断・失敗時

- 公開鍵・ownertrust・shadow keyの復元とストア配置は一括トランザクションではない。後段で失敗しても、復元済みのGPG状態を自動で削除・巻き戻ししない。
- ストアを配置する前なら、原因を解消して再実行できる。配置中の失敗では新規ディレクトリに一部だけ残ることがあるため、内容を確認する。スクリプトはそこを自動削除しない。完了後の再実行も既存ストアを保護するため停止する。
- 通常の終了・エラー・INT/TERMでは、この実行が作った作業領域とロックを削除する。SIGKILLや電源断では、ホーム直下の `.restore-pass.XXXXXXXX` と `.restore-pass.lock` が残り得る。実行中でないことと実パス・内容を確認してから片付ける。他のファイルをまとめて削除しない。
- GPGの生のエラーには機密情報が混ざり得るため、段階名と安全なエラーメッセージを表示する。PINやパスフレーズをログ・引数・環境変数で渡さない。

実装はGnuPGの機械可読な鍵一覧・復号ステータスと、agent/scdaemonの応答を検証する。[GnuPG: DETAILS](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/doc/DETAILS)、[agent READKEY / KEYINFO](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/agent/command.c)、[scdaemon LEARN](https://www.gnupg.org/documentation/manuals/gnupg/Scdaemon-LEARN.html)

以下の6.1〜6.5は、処理内容を理解するための手動手順。スクリプト実行に追加して重ねて実行する必要はない。

### 6.1 ストアを一時領域へ取得する
まず暗号化済みストアを取得する。GPG復号がまだできなくてもcloneと手順書の参照は可能。
```sh
umask 077
PASS_BACKUP="$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/pass"
RESTORE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pass-restore.XXXXXXXX")"
chmod 700 "$RESTORE_ROOT"

git clone --origin origin \
  "$PASS_BACKUP/password-store-p256-git.bundle" \
  "$RESTORE_ROOT/password-store"
git -C "$RESTORE_ROOT/password-store" fsck --full
git -C "$RESTORE_ROOT/password-store" status --short
```

GitHubから取得する場合は、cloneの取得元だけを確認済みのリポジトリURLに置き換える。両方のcloneを実行しない。Gitの整合性チェックだけではバックアップの新しさ・取得元の正当性は保証されないため、想定したコミットかも確認する。

詳細な鍵構成・バックアップの説明は、復元したストアの `.github/README.md` にある。既存環境での所在は `~/.password-store/.github/README.md`。秘密エントリを復号せず読めるため、全YubiKey喪失時にもこの文書を参照できる。

### 6.2 公開鍵と信頼設定を復元する
単独で保存した公開鍵を使う場合:
```sh
PASS_PUBLIC_KEY="$PASS_BACKUP/public.asc"
gpg --show-keys --with-subkey-fingerprint --with-keygrip "$PASS_PUBLIC_KEY"
```

単独の公開鍵がない場合に限り、archiveから `public.asc` **だけ**を抽出する。ここで入力するのはarchiveのage復旧パスフレーズで、PIV PINではない。
```sh
(
  set -o pipefail
  age --decrypt "$PASS_BACKUP/password-store-p256-recovery.tar.age" |
    tar -x -C "$RESTORE_ROOT" ./public.asc
) && echo "Public key extraction: OK"
```

`Public key extraction: OK` が表示された場合だけ、次へ進む。

```sh
PASS_PUBLIC_KEY="$RESTORE_ROOT/public.asc"
gpg --show-keys --with-subkey-fingerprint --with-keygrip "$PASS_PUBLIC_KEY"
```

表示された主鍵・P-256暗号化副鍵の完全なfingerprintとkeygripを、旧Macやオフラインの記録と照合する。名前・メールアドレス・短いKey IDだけでは判断しない。予期しない鍵、期限切れ・失効した鍵、秘密鍵を含むファイルならここで止める。

以下の説明用の値を照合済みの値へ置き換えてから実行する。副鍵の変数には末尾の `!` を含めない。
```sh
PASS_PRIMARY_FPR='照合済みの主鍵の完全なfingerprint'
PASS_ENCRYPTION_FPR='照合済みのP-256暗号化副鍵の完全なfingerprint'
gpg --import "$PASS_PUBLIC_KEY"
gpg --edit-key "$PASS_PRIMARY_FPR"
```

GPGの対話画面で `trust` を入力し、**自分自身の鍵であると照合できた主鍵だけ**に `ultimate`（メニューの `5`）を設定する。確認に応答後、`quit` で終了する。既存の正しい設定は変更不要。

これは公開鍵のインポートとは別のownertrust設定。復号だけでなく新規登録・更新時の暗号化も検証する。バックアップの `ownertrust.txt` を復元する方法もあるが、無関係な鍵まで上書きしないよう対象を確認する。`--trust-model always` による検証の無効化では代用しない。[GnuPG公式: 鍵の編集・信頼設定](https://www.gnupg.org/documentation/manuals/gnupg24/gpg.1.html)、[ownertrustの復元](https://gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html)

### 6.3 既存YubiKeyとの関連付けを復元する
PrimaryまたはSecondaryを1本だけ接続する。
```sh
gpgconf --kill scdaemon
gpg-card list
gpg-card checkkeys
gpg-card checkkeys --ondisk
gpg --list-secret-keys --with-subkey-fingerprint --with-keygrip "$PASS_PRIMARY_FPR"
```

確認する状態:
- `Application type` が `PIV`、対象が `PIV.9D`、algorithmが `nistp256`。
- PIV 9Dのkeygripが、公開鍵のP-256副鍵および記録と一致する。
- `checkkeys` で対象鍵が `shadowed`、`--ondisk` に対象鍵のsoftware copyが出ない。
- GPGの対象副鍵が `ssb>`。主鍵や旧RSA副鍵の秘密鍵は通常のpass利用に不要なので、`sec#` / `ssb#` を解消する目的で `secret.asc` を取り込まない。

`checkkeys` は不足するshadow keyを作成する操作でもある。`clear` / `protected` が出た場合は秘密鍵のsoftware copyがあるため、PIV-onlyとして完了にしない。この手順では鍵削除を行わず、状態を確認してから別途対処する。[GnuPG公式: checkkeysとPIV](https://www.gnupg.org/documentation/manuals/gnupg24/gpg-card.1.html)

### 6.4 ストアを書き換えずに検証する
現在の構成では `.gpg-id` はP-256副鍵のfingerprintに `!` を付けた1行。次の比較が終了コード0になることを確認する。不一致でも `.gpg-id` を書き換えて進めない。
```sh
printf '%s!\n' "$PASS_ENCRYPTION_FPR" |
  cmp - "$RESTORE_ROOT/password-store/.gpg-id"
```

実在するエントリ名（相対パス、末尾の `.gpg` なし）に置き換えて復号する。内容は表示・保存しない。
```sh
PASS_TEST_ENTRY='復号確認に使う既存エントリ名'
PASSWORD_STORE_DIR="$RESTORE_ROOT/password-store" \
  pass show "$PASS_TEST_ENTRY" >/dev/null && echo "PIV recovery: OK"
```

PIN入力・Touchの要否はカードのポリシーとキャッシュ状態による。PINを推測して繰り返し入力しない。Primary/Secondaryは1本ずつ接続し直し、6.3の確認と実エントリの復号をそれぞれ行う。  
さらに、ストア外の一時領域で、秘密ではないテスト文字列の暗号化・復号を確認する。
```sh
(
  set -o pipefail
  printf 'pass recovery test\n' |
    gpg --batch --encrypt --recipient "${PASS_ENCRYPTION_FPR}!" \
      --output "$RESTORE_ROOT/roundtrip.gpg" &&
    gpg --decrypt "$RESTORE_ROOT/roundtrip.gpg" |
      cmp - <(printf 'pass recovery test\n')
) && echo "Encryption/decryption: OK"
```

これはストアへの追加・編集・commitを行わない。再実行時は、既存の `roundtrip.gpg` を無条件に上書きせず、新しいテスト出力名を使う。秘密鍵のsoftware copyが残っていると、復号成功だけではYubiKeyを使用した証明にはならないため、6.3の確認も必要。

### 6.5 検証済みストアを配置する
全検証が成功してから行う。配置中は別のターミナルやアプリからpassword-storeを作成・更新しない。
```sh
if [ -e "$HOME/.password-store" ] || [ -L "$HOME/.password-store" ]; then
  echo "STOP: ~/.password-store already exists; do not overwrite it." >&2
else
  /bin/mv "$RESTORE_ROOT/password-store" "$HOME/.password-store"
fi
```

既存ディレクトリやシンボリックリンクがあれば中止する。自動削除・上書き・mergeはしない。`pass init` も実行しない。受信者の変更に伴って既存ファイルの再暗号化が起こり得る操作であり、復元済みストアの利用開始には不要。[pass公式: initとPASSWORD_STORE_DIR](https://git.zx2c4.com/password-store/about/)

配置できた場合、通常の `pass show "$PASS_TEST_ENTRY" >/dev/null` でも成功を確認する。bundleからのcloneでは `origin` がbundleのパスになるので、GitHubへの同期を再開する前に、確認済みのリポジトリURLへ変更する。
```sh
git -C "$HOME/.password-store" remote -v
# 以下の値を実際のpassword-storeリポジトリURLに置き換える
PASS_REMOTE='確認済みのGitHubリポジトリURL'
git -C "$HOME/.password-store" remote set-url origin "$PASS_REMOTE"
git -C "$HOME/.password-store" remote -v
```

既にGitHubからcloneした場合、URLが正しければ変更不要。ここではpushしない。GitのSSH認証・SSH署名はPIVによるpassの復号とは別なので、それぞれ確認する。GPG主鍵の秘密鍵をGit署名のために復元する必要はない。[Git公式: cloneとorigin](https://git-scm.com/docs/git-clone)

最後に `RESTORE_ROOT` の実パスと残った公開鍵・テスト暗号文を確認し、不要な一時ディレクトリをFinderで削除する。iCloudのバックアップと配置済みストアは残す。

### 全YubiKeyを失った場合の緊急復旧
通常移行とは分ける。YubiKeyを認識できないという理由だけでsoftware秘密鍵の復元へ切り替えない。  
1. 6.1で最新の外部bundleを一時領域へcloneし、`.github/README.md` の「B. YubiKeyをすべて失った場合」と「software recovery 後に PIV-only へ戻す」を読む。GitHubやpassの復号に依存せず参照できる。
2. `password-store-p256-recovery.tar.age` を専用の非共有作業領域で復号し、内部の `manifest.sha256` を検証する。age復旧パスフレーズは復旧前のpassやiCloudだけに依存させない。
3. まず通常環境とは別の、権限 `0700` の専用 `GNUPGHOME` で `secret.asc` と必要なownertrustを復元し、最新ストアを復号できるか検証する。関連するGPG・passコマンドはすべて同じ専用GNUPGHOMEを明示し、通常の `~/.gnupg` に混入させない。
4. この状態はsoftware復旧であり、YubiKey必須の状態ではない。通常環境への取り込みや新YubiKeyへのPIV 9Dの書き込みは、対象とバックアップを確認する独立した管理作業として判断する。
5. 検証後は専用GNUPGHOMEのGnuPGデーモンを終了し、復元した秘密鍵と平文の作業ファイルを適切に片付ける。SSD上の削除が完全消去を保証するわけではない。暗号化済みの復旧バックアップは保持する。

実際のPIN・秘密鍵・鍵の詳細な復旧資料はpassword-store側とオフラインの記録で管理し、この公開ドキュメントへ転記しない。

## 検証
`scripts/tests/setup-test.sh` は実際の秘密鍵やmacOS設定を使わず、一時データで復旧・失敗時の動作を検証する。macOSの `/bin/bash`、Determinate Nixと、flakeで固定したbootstrap-toolsが必要。lazy treesを有効にした最小flakeから暗号化ファイルを取得し、実ファイルとして読み取って復号できることも検証する。隔離したHOMEでは、暗号化SSH設定の復元、作業ディレクトリ削除後の通常chezmoiコマンド、初期化記録・適用履歴の保持、再実行時のrun_once重複防止、既存設定の保護を検証する。テスト用秘密鍵はNixストアへコピーしない。

```sh
nix build --no-update-lock-file --no-link --print-out-paths ./nix#bootstrap-tools
# 上の出力パスを渡す
/bin/bash scripts/tests/setup-test.sh /nix/store/…-dotfiles-bootstrap-tools
```

新Macでのsudo適用、Homebrewインストール、GUI認証までをこのテストが保証するわけではない。

`scripts/tests/restore-pass-test.sh` はセットアップ済みのApple Silicon Macで実行する。生成したGPG/age鍵とGit bundle、模擬カード応答だけを使い、実際の鍵・YubiKey・password-storeにはアクセスしない。

```sh
/bin/bash scripts/tests/restore-pass-test.sh
```

このテストは実機でのPIV・PIN/Touch・pinentryの動作を保証しない。実機確認は、新Macで本人が通常移行を実行する工程として分ける。

## Ref
- [Apple: Command Line Tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools)
- [Determinate Nix](https://docs.determinate.systems/determinate-nix/)
- [chezmoi init](https://www.chezmoi.io/reference/commands/init/)、[apply](https://www.chezmoi.io/reference/commands/apply/)、[status](https://www.chezmoi.io/reference/commands/status/)
- [Nix build](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-build)
- [nix-darwinの起動処理](https://github.com/nix-darwin/nix-darwin/blob/master/pkgs/nix-tools/darwin-rebuild.sh)、[/etcの衝突検査](https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/etc.nix)
- [sops-nix Home Manager実装](https://github.com/Mic92/sops-nix/blob/master/modules/home-manager/sops.nix)
