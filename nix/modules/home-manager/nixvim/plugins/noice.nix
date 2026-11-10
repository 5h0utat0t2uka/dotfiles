{ ... }:

{
  plugins.notify = {
    enable = true;
    lazyLoad.settings.event = "DeferredUIEnter";
    settings = {
      stages = "static";
      timeout = 3000;
      render = "default";
    };
  };
  plugins.noice = {
    enable = true;
    lazyLoad.settings.event = "DeferredUIEnter";
    settings = {
      cmdline = {
        format = {
          cmdline = {
            title = "";
            pattern = "^:";
            icon = "";
            lang = "vim";
          };
          input = {
            title = "";
            icon = "";
          };
          search_down = {
            title = "";
            kind = "search";
            pattern = "^/";
            icon = "";
            lang = "regex";
          };
          search_up = {
            title = "";
            kind = "search";
            pattern = "^%?";
            icon = "";
            lang = "regex";
          };
          filter = {
            title = "";
            pattern = "^:%s*!";
            icon = "";
            lang = "bash";
          };
          lua = {
            title = "";
            pattern = "^:%s*lua%s+";
            icon = "";
            lang = "lua";
          };
          help = {
            title = "";
            pattern = "^:%s*he?l?p?%s+";
            icon = "";
          };
        };
      };
      lsp = {
        override = {
          "vim.lsp.util.convert_input_to_markdown_lines" = true;
          "vim.lsp.util.stylize_markdown" = true;
          "cmp.entry.get_documentation" = false;
        };
      };
      presets = {
        command_palette = true;
        long_message_to_split = true;
        inc_rename = false;
        lsp_doc_border = true;
      };
      views = {
        notify = {
          replace = false;
          merge = false;
        };
        cmdline_popup = {
          position = {
            row = "50%";
            col = "50%";
          };
          size = {
            min_width = 60;
            width = "auto";
            height = "auto";
          };
          border = {
            style = "rounded";
            padding = [
              1
              1
            ];
          };
          win_options = {
            winblend = 10;
            winhighlight = {
              Normal = "NormalFloat";
              FloatBorder = "FloatBorder";
              Search = "NormalFloat";
              CurSearch = "NormalFloat";
              IncSearch = "NormalFloat";
            };
          };
        };
      };
      routes = [
        {
          view = "split";
          filter = {
            event = "msg_show";
            min_height = 10;
          };
        }
        {
          view = "split";
          filter = {
            event = "msg_show";
            min_length = 200;
          };
        }
        {
          filter = {
            event = "msg_show";
            kind = "search_count";
          };
          opts = {
            skip = true;
          };
        }
      ];
    };
  };
}
