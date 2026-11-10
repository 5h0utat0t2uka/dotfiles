{ ... }:

{
  plugins.toggleterm = {
    enable = true;
    lazyLoad.settings = {
      cmd = "ToggleTerm";
      keys = [
        {
          __unkeyed-1 = "<C-t>";
          mode = "n";
          __unkeyed-2 = "<cmd>ToggleTerm direction=float<CR>";
          desc = "Toggle floating terminal";
        }
        {
          __unkeyed-1 = "<C-t>";
          mode = "t";
          __unkeyed-2 = "<C-\\><C-n><cmd>ToggleTerm direction=float<CR>";
          desc = "Toggle floating terminal";
        }
        # {
        #   __unkeyed-1 = "<C-g>";
        #   mode = "n";
        #   __unkeyed-2.__raw = ''
        #     function()
        #       require("toggleterm.terminal").Terminal
        #         :new({ cmd = "lazygit", hidden = true })
        #         :toggle()
        #     end
        #   '';
        #   desc = "Toggle lazygit";
        # }
      ];
    };
    settings = {
      size.__raw = ''
        function(term)
          if term.direction == "horizontal" then
            return 15
          end
          return 20
        end
      '';
      open_mapping = "[[<c-t>]]";
      hide_numbers = true;
      shade_filetypes = [ ];
      highlights = { };
      autochdir = false;
      shade_terminals = false;
      start_in_insert = true;
      insert_mappings = false;
      terminal_mappings = true;
      persist_size = true;
      persist_mode = true;
      direction = "float";
      close_on_exit = true;
      clear_env = false;
      shell.__raw = "vim.o.shell";
      auto_scroll = true;
      highlights = {
        FloatBorder = {
          guifg = "#4C566A";
          guibg = "NONE";
        };
        NormalFloat = {
          guibg = "NONE";
        };
      };
      float_opts = {
        border = "curved";
        title_pos = "center";
        winblend = 3;
      };
      winbar = {
        enabled = false;
        name_formatter.__raw = ''
          function(term)
            return term.name
          end
        '';
      };
    };
    #     luaConfig.post = ''
    #       local Terminal = require("toggleterm.terminal").Terminal
    #       local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })
    #       _G._lazygit_toggle = function()
    #         lazygit:toggle()
    #       end
    #
    #       vim.keymap.set("n", "<C-g>", _G._lazygit_toggle, {
    #         noremap = true,
    #         silent = true,
    #         desc = "Toggle lazygit",
    #       })
    #     '';
  };
}
