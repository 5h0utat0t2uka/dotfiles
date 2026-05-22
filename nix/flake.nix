{
  # ============================================================
  # - darwinConfigurations は ./hosts/darwin 配下のホスト名のディレクトリから自動生成する
  # - 各 host は `./hosts/darwin/<ホスト名>/identity.nix` を持ち、その `identity.hostname` が <ホスト名> と一致することを `assert` で強制する
  # - setup.sh / Justfile から `darwin-rebuild` を呼ぶと、対象ホスト名の modules が合成されて switch/build される
  # ============================================================

  description = "macOS dotfiles with nix-darwin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wezterm = {
      url = "github:wezterm/wezterm?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, darwin, home-manager, nix-homebrew, wezterm, ... } @inputs:
  let
    lib = nixpkgs.lib;
    # ------------------------------------------------------------
    # ./hosts/darwin 以下のディレクトリ名を hostKey とする
    # ------------------------------------------------------------
    darwinHostsDir = ./hosts/darwin;
    darwinHostKeys = lib.attrNames(lib.filterAttrs (_name: type: type == "directory")(builtins.readDir darwinHostsDir));

    # ------------------------------------------------------------
    # hostKey から identity を読み込む
    # ------------------------------------------------------------
    identityFor = hostKey: import (darwinHostsDir + "/${hostKey}/identity.nix");

    # ------------------------------------------------------------
    # hostKey -> darwinConfigurations.<hostKey> を生成する関数
    # - ディレクトリ名と identity.hostname を assert で強制して一致させる
    # ------------------------------------------------------------
    mkDarwinConfig = hostKey:
    let
      identity = identityFor hostKey;
    in
    # identity に hostname があること、かつ hostKey と一致することを強制
    assert (identity ? hostname);
    assert (identity.hostname == hostKey);

    {
      name = identity.hostname;
      # nix-darwin のシステム定義
      value = darwin.lib.darwinSystem {
        system = identity.system;
        specialArgs = {
          inherit identity inputs;
        };
        modules = [
          # ----------------------------------------------------
          # キャッシュ
          # ----------------------------------------------------
          {
            nix.settings = {
              substituters = [
                "https://cache.nixos.org"
                "https://nix-community.cachix.org"
                "https://5h0uta.cachix.org"
              ];
              trusted-public-keys = [
                "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBo="
                "5h0uta.cachix.org-1:YrFB/6azmFXnXmmosBRBwB3lEKBpUq7Hn+tJvzTqtGc="
              ];
            };
          }

          # ----------------------------------------------------
          # nixpkgs 設定
          # ----------------------------------------------------
          {
            nixpkgs = {
              system = identity.system;
              config.allowUnfree = true;
              # overlay をここで追加
              overlays = [
                # tools
                (import ./overlays/tools/aicommits.nix { inherit inputs; })
                # (import ./overlays/tools/codex { inherit inputs; })
                # (import ./overlays/tools/claude-code { inherit inputs; })

                # fonts
                (import ./overlays/fonts/shcode-jp-zen-haku.nix)
              ];
            };
          }

          # ----------------------------------------------------
          # nix-homebrew 統合
          # - autoMigrate: 既存 Homebrew がある場合の移行
          # ----------------------------------------------------
          nix-homebrew.darwinModules.nix-homebrew
          ({ identity, ... }: {
            nix-homebrew = {
              enable = true;
              enableRosetta = false;
              user = identity.username;
              autoMigrate = false;
              mutableTaps = true;
            };
          })

          # ----------------------------------------------------
          # home-manager を nix-darwin 経由で統合
          # ----------------------------------------------------
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit identity inputs;
            };
          }

          # ----------------------------------------------------
          # ホスト入口:
          # ----------------------------------------------------
          (darwinHostsDir + "/${hostKey}/default.nix")
        ];
      };
    };

    # ------------------------------------------------------------
    # 全 hostKey について mkDarwinConfig を map して attrset 化
    # ------------------------------------------------------------
    darwinConfigurations = builtins.listToAttrs (map mkDarwinConfig darwinHostKeys);
  in
  {
    inherit darwinConfigurations;
    formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
  };
}
