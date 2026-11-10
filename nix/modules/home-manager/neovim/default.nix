# modules/home-manager/neovim/default.nix
{
  config,
  pkgs,
  identity,
  ...
}:

let
  configRoot = "${identity.flakeRoot}/modules/home-manager/neovim/config";
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
    initLua = builtins.readFile ./config/init.lua;
    extraPackages = with pkgs; [ ];
  };

  xdg.configFile = {
    # Nix store の mtime epoch 0 により vim.loader のバイトコードキャッシュが古いままロードされ続ける問題を回避するため、Nix store を経由しない
    # 直接リンク（mkOutOfStoreSymlink）で配置するので、設定変更は darwin-rebuild switch なしで即反映されるようになる
    "nvim/lazy-lock.json".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/lazy-lock.json";
    "nvim/.luarc.json".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/.luarc.json";
    "nvim/lua".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/lua";
    "nvim/after".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/after";
    "nvim/snippets".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/snippets";
  };
}
