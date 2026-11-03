{ pkgs, ... }:

let
  previewer = pkgs.writeShellScript "lf-pv" (builtins.readFile ./bin/preview.sh);
in
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
      J = "preview-scroll down";
      K = "preview-scroll up";
    };
    commands = {
      on-select = "set user_preview_offset 0";
      preview-scroll = ''%${previewer} --scroll "$1"'';
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
    previewer.source = previewer;
  };
}
