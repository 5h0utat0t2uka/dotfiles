# Dotfiles
ドットファイルを[chezmoi](https://www.chezmoi.io/)で運用する

## ドットファイルの追加
``` shell
chezmoi add ~/.zshrc
```

## ドットファイルの編集と確認
``` shell
chezmoi edit ~/.zshrc
chezmoi diff
```

## ドットファイルの反映
``` shell
chezmoi apply ~/.zshrc

# シェルに変更を反映
exec $SHELL -l
```

## ドットファイルの変更をリポジトリに反映
``` shell
chezmoi cd # ソースディレクトリに入る
git add .
git commit -m "Update .zshrc"
git push
```

## ドットファイルの管理を除外
``` shell
chezmoi forget ~/.zshrc

# 更にホームディレクトリからも削除する場合は下記
chezmoi destroy ~/.zshrc
```

## テンプレートファイルの更新
``` shell
# エディタで編集
chezmoi edit-config-template
```
テンプレートを実体に反映（上書き）
```
chezmoi execute-template < ~/.local/share/chezmoi/.chezmoi.toml.tmpl > ~/.config/chezmoi/chezmoi.toml
```
あるいはテンプレートから設定を再生成して`apply`で反映
```
chezmoi init --apply
```

## 管理対象外のファイルの更新
``` shell
chezmoi cd     # ソースディレクトリに入る
vim README.md  # エディタで編集
git add README.md
git commit -m "Update README"
git push
```

## nvim
- セットアップを行う場合
``` shell
chezmoi apply
nvim --headless "+Lazy! sync" +qa
```

- プラグイン追加の手順
1. `~/.config/nvim/lua/plugins/<plugin>.lua`に追加するプラグインの設定ファイルを追加後
2. 以下のコマンドで追加
``` shell
chezmoi add ~/.config/nvim/lua/plugins/<plugin>.lua    # chezmoiに追加
nvim --headless "+Lazy! sync" +qa                      # nvimのプラグインを同期（インストール）
chezmoi add ~/.config/nvim/lazy-lock.json              # インストール後に生成されたロックファイルをchezmoiに追加
```

- プラグイン削除の手順
1. 以下のコマンドで削除
``` shell
chezmoi forget ~/.config/nvim/lua/plugins/<plugin>.lua # chezmoiから外す
nvim --headless "+Lazy! sync" +qa                      # nvimのプラグインを同期（アンインストール）
chezmoi add ~/.config/nvim/lazy-lock.json              # アンインストール後に生成されたロックファイルをchezmoiに追加

rm ~/.config/nvim/lua/plugins/<plugin>.lua             # 管理から外れてもホームディレクトリ側には残るので、完全に消すなら`rm`する
```

