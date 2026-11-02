{ pkgs, ... }:

{
  programs.lf = {
    enable = true;
    settings = {
      borderstyle = "roundoutline";
      drawbox = true;
      # roundbox = true;
      icons = true;
      info = "size:perm:time";
      hidden = true;
      preview = true;
      borderfmt = "\\033[38;2;59;66;82m";
      promptfmt = "\\033[34;1m%d\\033[0m\\033[1m%f\\033[0m";
      cursorpreviewfmt = "\\033[0m";
    };
    keybindings = {
      e = ''$sh -lc 'nvim "$f"' '';
    };
    commands = {
      open = ''
        ''${{
          case "$(file --mime-type -Lb "$f")" in
            text/*|application/json|application/xml|application/javascript)
              sh -lc 'nvim "$f"'
              ;;
            *)
              "$OPENER" "$f"
              ;;
          esac
        }}
      '';
    };
    previewer.source = pkgs.writeShellScript "lf-pv" (builtins.readFile ./bin/preview.sh);
  };
}
