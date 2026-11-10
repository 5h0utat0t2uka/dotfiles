{ pkgs, ... }:

{
  home.packages = with pkgs; [ glow ];
  xdg.configFile."glow/glow.yml".text = ''
    style: "dark"
    mouse: true
    pager: true
    width: 100
    all: false
    showLineNumbers: false
    preserveNewLines: false
  '';
}
