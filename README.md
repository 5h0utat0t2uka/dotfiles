
# macOS dotfiles with nix and chezmoi  

<img alt="nix-check" src="https://img.shields.io/github/actions/workflow/status/5h0utat0t2uka/dotfiles/nix-check.yml?branch=main&style=for-the-badge&label=nix-check"/> <img alt="技術者倫理 遵守済み" src="https://img.shields.io/badge/%E6%8A%80%E8%A1%93%E8%80%85%E5%80%AB%E7%90%86-%E9%81%B5%E5%AE%88%E6%B8%88%E3%81%BF-0a0a0a?style=for-the-badge&labelColor=ffffff"/>

## nix flake update  
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
