{ inputs, pkgs, identity, ... }:

let
  username = identity.username;
  homeDirectory = identity.homeDirectory;
in

{
  imports = [
    ../../../modules/nix-darwin/system.nix
    ../../../modules/nix-darwin/shell.nix
    ../../../modules/nix-darwin/homebrew.nix
    ../../../modules/nix-darwin/launchd.nix
  ];

  home-manager.users.${username} = {
    imports = [
      inputs.sops-nix.homeManagerModules.sops
      # ../../../modules/home-manager/ghostty
      ../../../modules/home-manager/wezterm
      ../../../modules/home-manager/tmux
      ../../../modules/home-manager/git
      ../../../modules/home-manager/zsh
      ../../../modules/home-manager/starship
      ../../../modules/home-manager/pass
      ../../../modules/home-manager/sops
      ../../../modules/home-manager/nixvim
      # ../../../modules/home-manager/neovim
      ../../../modules/home-manager/direnv
      ../../../modules/home-manager/lazygit
      ../../../modules/home-manager/aicommit2
      # ../../../modules/home-manager/aicommits
      ../../../modules/home-manager/aerospace
      ../../../modules/home-manager/glow
      ../../../modules/home-manager/jqp
      ../../../modules/home-manager/bat
      ../../../modules/home-manager/lf
      ../../../modules/home-manager/nb
      # ../../../modules/home-manager/zed
    ];
    manual = {
      # FIXME: issue: problem with home-manager manual (https://github.com/nix-community/home-manager/issues/7935)
      manpages.enable = false;
    };
    home = {
      stateVersion = "25.11";
      username = username;
      homeDirectory = homeDirectory;
      packages = with pkgs; [
        chafa
        devbox
        doggo
        dust
        eza
        fd
        fzf
        gh
        gitleaks
        gifski
        gnupg
        hyperfine
        just
        jq
        libwebp
        macism
        # mise
        ni
        nix-output-monitor
        nmap
        nodejs_24
        opentofu
        pre-commit
        pnpm
        pinentry_mac
        ripgrep
        tree-sitter
        tree
        viu
        wget
        xh
        zbar
        zizmor
        zoxide
        nixd
        nil
        lua-language-server
        tofu-ls
        vscode-langservers-extracted
        copilot-language-server
      ];
    };
  };
}
