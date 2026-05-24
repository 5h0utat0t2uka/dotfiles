{
  # ============================================================
  # - darwinConfigurations は ./hosts/darwin 配下のホスト名のディレクトリから生成する
  # - host は `./hosts/darwin/<ホスト名>/identity.nix` を持ち、その `identity.hostname` が <ホスト名> と一致することを `assert` で強制する
  # - setup.sh / Justfile から `darwin-rebuild` を呼ぶと、対象ホスト名の modules が合成されて switch/build する
  # ============================================================

  description = "macOS configuration with nix-darwin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
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

  outputs = inputs@{ nixpkgs, darwin, home-manager, nix-homebrew, ... }:
  let
    inherit (nixpkgs) lib;

    # ------------------------------------------------------------
    # ./hosts/darwin 以下のディレクトリ名を hostKey とする
    # ------------------------------------------------------------
    darwinHostsDir = ./hosts/darwin;
    darwinHostKeys = lib.attrNames(lib.filterAttrs (_name: type: type == "directory")(builtins.readDir darwinHostsDir));

    # ------------------------------------------------------------
    # hostKey から identity を読み込む
    # ------------------------------------------------------------
    identityFor = hostKey: import (darwinHostsDir + "/${hostKey}/identity.nix");

    # ----------------------------------------------------
    # nix.settings module
    # ----------------------------------------------------
    nixSettingsModule = {
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
    };

    # ----------------------------------------------------
    # nixpkgs module
    # ----------------------------------------------------
    nixpkgsModule = { identity, inputs, ... }: {
      nixpkgs = {
        hostPlatform = identity.system;
        config.allowUnfree = true;
        overlays = [
          # tools
          (import ./overlays/tools/aicommits.nix { inherit inputs; })
          # (import ./overlays/tools/codex { inherit inputs; })
          # (import ./overlays/tools/claude-code { inherit inputs; })

          # fonts
          (import ./overlays/fonts/shcode-jp-zen-haku.nix)
        ];
      };
    };

    # ----------------------------------------------------
    # home-manager module
    # ----------------------------------------------------
    homeManagerModule = { identity, inputs, ... }: {
      imports = [
        home-manager.darwinModules.home-manager
      ];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit identity inputs;
        };
      };
    };

    # ----------------------------------------------------
    # nix-homebrew module
    # ----------------------------------------------------
    nixHomebrewModule = { identity, ... }: {
      imports = [
        nix-homebrew.darwinModules.nix-homebrew
      ];
      nix-homebrew = {
        enable = true;
        enableRosetta = false;
        user = identity.username;
        autoMigrate = false;
        mutableTaps = true;
      };
    };

    # ------------------------------------------------------------
    # hostKey -> darwinConfigurations.<hostKey> を生成する
    # ディレクトリ名と identity.hostname を assert で強制
    # ------------------------------------------------------------
    mkDarwinConfig = hostKey:
    let
      identity = identityFor hostKey;
    in
    assert lib.assertMsg (identity ? hostname) "hosts/darwin/${hostKey}/identity.nix must define `hostname`";
    assert lib.assertMsg (identity ? username) "hosts/darwin/${hostKey}/identity.nix must define `username`";
    assert lib.assertMsg (identity ? system) "hosts/darwin/${hostKey}/identity.nix must define `system`";
    assert lib.assertMsg (identity.hostname == hostKey) "`identity.hostname` must match directory name `${hostKey}`";

    {
      name = identity.hostname;
      value = darwin.lib.darwinSystem {
        inherit (identity) system;
        specialArgs = {
          inherit identity inputs;
        };
        modules = [
          nixSettingsModule
          nixpkgsModule
          homeManagerModule
          nixHomebrewModule

          # ----------------------------------------------------
          # host entry
          # ----------------------------------------------------
          (darwinHostsDir + "/${hostKey}/default.nix")
        ];
      };
    };

    supportedSystems = [
      "aarch64-darwin"
    ];
    forAllSystems = lib.genAttrs supportedSystems;
  in
  {
    darwinConfigurations = builtins.listToAttrs (map mkDarwinConfig darwinHostKeys);
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
  };
}
