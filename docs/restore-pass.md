# pass/password-storeの復旧手順

[Macの復旧](setup.md)が完了した新Macで実行する。既存YubiKeyの **PIV 9D** を使う手順で、passageは対象外。
以降は同じzshまたはBashのターミナルで順番に実行し、エラーが出たら止める。`sudo`・実行ログの保存・`set -x` は使わない。

## 1. 準備する
- 新Macに `~/.password-store` がないことを確認する。空ディレクトリやシンボリックリンクも不可。既存ストアを削除して進めない。
- 既存のYubiKeyを1本と、そのPIV PINを用意する。全YubiKeyを失った場合は[別の復旧手順](setup.md#emergency-pass-recovery)を使う。
- 通常の `~/.gnupg` を使い、独自の `GNUPGHOME`・`PASSWORD_STORE_*` による復旧先・鍵・オプションの上書きは使わない。
- Finderで以下のファイルをiCloudからダウンロードし、archiveの復旧パスフレーズを用意する。

```text
~/Library/Mobile Documents/com~apple~CloudDocs/share/pass/
├── password-store-p256-git.bundle
└── password-store-p256-recovery.tar.age
```

最新のコミット済みストアを含む、単独でclone可能な外部bundleを使う。未コミット・未追跡の変更は復元されない。[Git公式: bundle](https://git-scm.com/docs/git-bundle)

## 2. 引数を設定する
`PASS_TEST_ENTRY` をbundle内に実在するエントリ名（相対パス、末尾の `.gpg` なし）へ置き換える。
記載済みの3つの鍵識別子は旧Macまたは独立した記録と照合し、鍵を変更している場合は更新する。空白・末尾の `!` は付けない。旧RSA副鍵と取り違えない。

```bash
cd "$HOME/.local/share/chezmoi"

PASS_BACKUP="$HOME/Library/Mobile Documents/com~apple~CloudDocs/share/pass"
PASS_TEST_ENTRY='復号確認に使う既存エントリ名'

pass_restore_args=(
  --backup-dir "$PASS_BACKUP"
  --recovery-archive "$PASS_BACKUP/password-store-p256-recovery.tar.age"
  --primary-fingerprint 'BC4B4FD345E598E53EE9DE87AEDCA1768E7F652A'
  --encryption-fingerprint '9635C1F345BD86AE145260B06996C12830B35019'
  --keygrip '2C96179D998C857055143F82B4E6C9511B8F760F'
  --test-entry "$PASS_TEST_ENTRY"
)
```

この例はarchiveから `./public.asc` だけを取り出す。現在のP-256副鍵を含む単独の公開鍵を使う場合は、配列の `--recovery-archive ...` の行を `--public-key "$PASS_BACKUP/public.asc"` に置き換える。併用・自動切り替えはしない。

## 3. 確認して復旧する
```bash
./scripts/restore-pass.sh --check "${pass_restore_args[@]}"
```

`Local checks passed.` が表示されたら次へ進む。この時点では鍵・bundleの内容や実際の復号は未検証。  
YubiKeyを **1本だけ**接続し、他のGPG操作・password-storeの更新を止めて実行する。
```bash
./scripts/restore-pass.sh --apply "${pass_restore_args[@]}"
```

1. ageのプロンプトに **archive用の復旧パスフレーズ**を入力する。
2. 表示されたコミット・鍵識別子が意図したものと一致する場合だけ、確認に `restore` と入力する。
3. 復号時に要求されたら **PIV PIN / Touch** に応じる。PINを推測して繰り返し入力しない。

`pass restoration completed.` が表示されたら、通常の配置先で復号を確認する。
```bash
pass show "${PASS_TEST_ENTRY:?既存エントリ名を設定してください}" >/dev/null &&
  printf 'pass: OK\n'
```

`pass: OK` が出れば、そのエントリの復号確認は完了。成功後にスクリプトを再実行しない。
`pass init`・秘密鍵のインポート・YubiKeyの初期化は不要。[pass公式: show / init](https://git.zx2c4.com/password-store/about/)

## 4. GitHubの同期先を設定する
**旧Mac**または独立した記録で、password-storeのGitHub URLを確認する。dotfilesのURLではない。
```bash
git -C "$HOME/.password-store" remote get-url origin
```

以降は **新Mac**で実行する。
```bash
git -C "$HOME/.password-store" remote -v
```

上の手順で復旧した場合、originは削除されている。originがない場合だけ、実際のURLへ置き換えて追加する。  
`--origin` を指定して復旧した場合など、すでに登録されていればURLを確認し、正しければ追加不要。不一致なら上書きせず止める。
```bash
git -C "$HOME/.password-store" remote add origin '確認済みのpassword-storeのGitHub URL'
```

認証用のYubiKeyを接続して確認する。コミットIDと `HEAD` が表示されれば読み取りアクセスは成功。
```bash
git -C "$HOME/.password-store" ls-remote origin HEAD
```

## 5. 履歴を確認して同期する
```bash
git -C "$HOME/.password-store" fetch origin
git -C "$HOME/.password-store" branch --show-current
git -C "$HOME/.password-store" for-each-ref \
  --format='%(refname:short)' refs/remotes/origin/
```

現在のブランチが `main`、同期先が `origin/main` と確認できた場合だけ次へ進む。異なる場合は対象を確認する。
```bash
git -C "$HOME/.password-store" status --porcelain=v1 --untracked-files=all
```

正常終了して何も表示されなければ、コミット数を比較する。変更があれば止める。
```bash
git -C "$HOME/.password-store" rev-list --left-right --count \
  HEAD...refs/remotes/origin/main
```

左が新Mac側だけ、右が取得済みGitHub側だけのコミット数。`0 0` または `0 N` の場合だけ次へ進む。左が1以上なら独自の履歴があるため止める。[Git公式: rev-list](https://git-scm.com/docs/git-rev-list)
```bash
git -C "$HOME/.password-store" branch --set-upstream-to=origin/main main
git -C "$HOME/.password-store" merge --ff-only --no-stat refs/remotes/origin/main
git -C "$HOME/.password-store" status --short --branch
```

この操作で新Macのファイルを更新する。fast-forwardできなければ停止する。強制push・resetで回避しない。[Git公式: merge](https://git-scm.com/docs/git-merge)  
最後の出力が次の1行だけなら、取得済みの履歴への同期は完了。
```text
## main...origin/main
```

同期後にも復号を確認する。対象エントリが移動・削除されていれば選び直す。
```bash
pass show "${PASS_TEST_ENTRY:?既存エントリ名を設定してください}" >/dev/null &&
  printf 'pass: OK\n'
```

`pass: OK` で完了。今回はpush不要。予備YubiKey・Git署名・全エントリの検証は別途行う。

## 失敗・中断した場合
- 引数エラー: 同じターミナルで手順2の変数・配列を定義し直す。
- `.gpg-id`・公開鍵・カードの不一致: バックアップ・P-256副鍵・PIV 9D keygripを照合する。受信者の書き換え、秘密鍵の取り込み、カードのリセットで回避しない。
- 古い `public.asc`: 照合済みarchiveを選び直し、`--check` から再実行する。
- 復号失敗: archiveのパスフレーズとPIV PINを区別し、不明なPINは試さない。
- 復旧途中の失敗: GPGの変更は自動で巻き戻らない。ストア未配置なら原因解消後に再実行できる。`~/.password-store` が作成済みなら、不完全な配置の可能性もあるため削除・再実行せず状態を確認する。
- 強制終了: 実行中でないことを確認し、`~/.restore-pass.lock` と残存する `~/.restore-pass.XXXXXXXX` を点検する。対象不明のまま削除しない。
