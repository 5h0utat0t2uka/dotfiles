{ pkgs, ... }:

{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "yy";
    settings = {
      preview = {
        wrap = "yes";
        max_width = 1200;
        max_height = 1200;
      };
    };
    initLua = ''
      local original_layout = Root.layout
      function Root:layout()
        original_layout(self)
        self._chunks[3] = self._chunks[3]:pad(ui.Pad.top(1))
      end
      Header:children_add(function()
        return ui.Span(" ")
      end, 500, Header.LEFT)

      -- 既存のモード表示とファイルサイズ表示を削除
      Status:children_remove(1, Status.LEFT)
      Status:children_remove(2, Status.LEFT)
      Status:children_remove(3, Status.LEFT)

      -- NOR [180B] の形式で表示
      Status:children_add(function(self)
        local mode = tostring(self._tab.mode):sub(1, 3):upper()
        local hovered = self._current.hovered
        local size = ya.readable_size(hovered and hovered.cha.len or 0)
        return ui.Line {
          ui.Span(" " .. mode .. "・" .. size .. " "):style(self:style().main),
        }
      end, 1000, Status.LEFT)

      Status:children_remove(4, Status.RIGHT)
      Status:children_remove(5, Status.RIGHT)
      Status:children_remove(6, Status.RIGHT)
    '';
    extraPackages = with pkgs; [
      file
    ];
    settings.mgr = {
      ratio = [
        1
        3
        3
      ];
      show_hidden = true;
      linemode = "permissions";
    };
    keymap.mgr.prepend_keymap = [
      {
        on = "<Backspace>";
        run = "remove";
        desc = "Trash selected files";
      }
      {
        on = "d";
        run = "noop";
      }
      {
        on = "q";
        run = "quit --no-cwd-file";
        desc = "Quit without changing directory";
      }
      {
        on = "Q";
        run = "quit";
        desc = "Quit and change directory";
      }
    ];

    theme = {
      icon = {
        globs = [ ];
        dirs = [ ];
        files = [ ];
        exts = [ ];
        conds = [ ];
      };
      mgr = {
        border_symbol = " ";
        # border_style = {
        #   fg = "black";
        # };
        cwd = {
          fg = "blue";
          bold = true;
        };
      };
      mode.normal_main = {
        fg = "blue";
        bg = "reset";
        bold = true;
      };
      indicator = {
        preview = {
          underline = false;
        };
      };

      status = {
        sep_left = {
          open = "";
          close = "";
        };
        sep_right = {
          open = "";
          close = "";
        };
      };
    };
  };
}
