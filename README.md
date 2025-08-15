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
chezmoi cd
git add .
git commit -- -m "Update zshrc"
git push
```

## ドットファイルの管理を除外
``` shell
chezmoi forget ~/.zshrc

# 更にホームディレクトリからも削除する場合は下記
chezmoi destroy ~/.zshrc
```

## neovim のセットアップ
``` shell
chezmoi apply
nvim --headless "+Lazy! sync" +qa
```
