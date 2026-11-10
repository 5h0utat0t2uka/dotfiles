{ pkgs, ... }:

{
  plugins.oil = {
    enable = true;
    lazyLoad.settings = {
      cmd = "Oil";
      ft = "directory";
      keys = [
        {
          __unkeyed-1 = "-";
          __unkeyed-2.__raw = ''
            function()
              require("oil").open(nil, {
                preview = {
                  split = "belowright",
                },
              })
            end
          '';
          desc = "Open parent directory with preview";
        }
      ];
    };
    settings = {
      default_file_explorer = true;
      columns = [
        "permissions"
        "mtime"
      ];
      win_options = {
        signcolumn = "yes:2";
        number = false;
        relativenumber = false;
      };
      view_options = {
        show_hidden = true;

        is_always_hidden.__raw = ''
          function(name, _)
            return name == "node_modules"
              or name == ".git"
              or name == ".next"
              or name == ".DS_Store"
              or name == "dist"
          end
        '';
      };
      preview_win = {
        update_on_cursor_moved = true;
        preview_method = "fast_scratch";
        disable_preview.__raw = ''
          function(filename)
            local f = filename:lower()
            return f:match("%.png$") ~= nil
              or f:match("%.jpe?g$") ~= nil
              or f:match("%.webp$") ~= nil
              or f:match("%.gif$") ~= nil
              or f:match("%.avif$") ~= nil
              or f:match("%.svg$") ~= nil
              or f:match("%.bmp$") ~= nil
              or f:match("%.ico$") ~= nil
              or f:match("%.ds_store$") ~= nil
          end
        '';
      };
      confirmation = {
        min_width = [
          40
          0.4
        ];
        max_width = 0.9;
        min_height = [
          5
          0.1
        ];
        max_height = 0.9;
        border = "rounded";
        win_options = {
          winblend = 0;
        };
      };
      keymaps = {
        "q" = {
          __unkeyed-1 = "actions.close";
          mode = "n";
        };
        "<C-p>" = {
          __unkeyed-1 = "actions.preview";
          opts = {
            split = "belowright";
          };
        };
      };
    };
    luaConfig.post = ''
      pcall(vim.cmd.packadd, "oil-git-status.nvim")
      require("oil-git-status").setup({
        show_ignored = true,
      })
      vim.api.nvim_set_hl(0, "OilFloat", { link = "Normal" })
      vim.api.nvim_set_hl(0, "OilFloatBorder", { link = "Normal" })
    '';
  };
  extraPlugins = [
    {
      plugin = pkgs.vimPlugins.oil-git-status-nvim;
      optional = true;
    }
  ];
}
