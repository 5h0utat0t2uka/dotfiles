{ pkgs, ... }:

{
  programs.zed-editor = {
    # NOTE:
    # 本体は modules/nix-darwin/homebrew.nix で管理する
    # 設定は chezmoi で管理する
    enable = false;
    package = pkgs.zed-editor;
    mutableUserSettings = false;
    mutableUserKeymaps = false;
    extensions = [
      "astro"
      "comment"
      "dockerfile"
      "emmet"
      "git-firefly"
      "html"
      "just"
      "lua"
      "make"
      "nix"
      "scss"
      "toml"
    ];
    userSettings = builtins.fromJSON (builtins.readFile ./settings.json);
    userKeymaps = builtins.fromJSON (builtins.readFile ./keymap.json);
    themes = {
      Nord-Custom = builtins.fromJSON (builtins.readFile ./themes/Nord-Custom.json);
    };
  };
}
