## Chezmoi
ドットファイルを[chezmoi](https://www.chezmoi.io/)で運用する

### ドットファイルの追加
``` shell
chezmoi add ~/.zshrc
```

### ドットファイルの編集と確認
``` shell
chezmoi edit ~/.zshrc
chezmoi diff
```

### ドットファイルの反映
``` shell
chezmoi apply ~/.zshrc
exec $SHELL -l
```

### ドットファイルの変更をリポジトリに反映
``` shell
chezmoi cd # ソースディレクトリに入る
git add .
git commit -m "Update .zshrc"
git push
```

### ドットファイルの管理を除外
``` shell
chezmoi forget ~/.zshrc

# 更にホームディレクトリからも削除する場合は下記
chezmoi destroy ~/.zshrc
```

### テンプレートファイルの更新
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

### 管理対象外のファイルの更新
``` shell
chezmoi cd     # ソースディレクトリに入る
vim README.md  # エディタで編集
git add README.md
git commit -m "Update README"
git push
```

---

## Neovim
![](/68544e5ef841.png)
プラグインマネージャーに[lazy.nvim](https://github.com/folke/lazy.nvim)を利用する場合の運用  
### セットアップの手順
``` shell
chezmoi apply
nvim --headless "+Lazy! sync" +qa
```

### プラグイン追加の手順
1. `~/.config/nvim/lua/plugins/<plugin>.lua`に追加するプラグインの設定ファイルを追加  
2. 以下のコマンドで追加
``` shell
chezmoi add ~/.config/nvim/lua/plugins/<plugin>.lua    # chezmoiに追加
nvim --headless "+Lazy! sync" +qa                      # nvimのプラグインを同期（インストール）
chezmoi add ~/.config/nvim/lazy-lock.json              # インストール後に生成されたロックファイルをchezmoiに追加
```

### プラグイン削除の手順
1. 以下のコマンドで削除
``` shell
chezmoi forget ~/.config/nvim/lua/plugins/<plugin>.lua    # chezmoiから外す
rm ~/.config/nvim/lua/plugins/<plugin>.lua                # ホームディレクトリ側の実体も削除
nvim --headless "+Lazy! sync" +qa                         # nvimのプラグインを同期（アンインストール）
chezmoi add ~/.config/nvim/lazy-lock.json                 # アンインストール後に生成されたロックファイルをchezmoiに追加

```

### プラグインの設定内容
`<Leader>`はスペースに割り当て
``` lua
vim.g.mapleader = " "
vim.g.maplocalleader = " "
```

#### [neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim)
ファイルエクスプローラー  
- `<Leader>e`でトグル

#### [telescope](https://github.com/nvim-telescope/telescope.nvim)
ファジーファインダー
- `<Leader>ff`でファイル検索
- `<Leader>fg`でグレップ
- `<Leader>fb`でバッファ一覧、ノーマルモードの場合は`dd`で、インサートモードの場合は`<C-d>`でバッファ削除

#### [toggleterm](https://github.com/akinsho/toggleterm.nvim)
フローティングでターミナル表示
- `<Leader>tt`でターミナル起動して表示・非表示をトグル
- `<Leader>lg`でlazygitを開く
> [!TIP]
> フォーカスが当たらない（入力できない）場合はインサートモード(`i`)にする

