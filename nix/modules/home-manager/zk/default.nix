{ config, pkgs, ... }:

{
  programs.zk = {
    enable = true;
    settings = {
      notebook.dir = "${config.home.homeDirectory}/Development/repositories/github.com/5h0utat0t2uka/notebook";
      tool = {
        editor = "nvim";
        fzf-preview = ''GLOW_PAGER=false CLICOLOR_FORCE=1 COLORTERM=truecolor ${pkgs.glow}/bin/glow --style dark --width "$FZF_PREVIEW_COLUMNS" {-1}'';
        # 色・レイアウト・プレビュー位置は zsh の FZF_DEFAULT_OPTS に任せる。
        fzf-options = "--tiebreak=begin --tabstop=4 --no-hscroll";
      };
    };
  };
}
