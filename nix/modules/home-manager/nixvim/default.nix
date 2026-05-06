# nix/modules/home-manager/nixvim/default.nix
{ inputs, ... }:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
  ];
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
    vimdiffAlias = true;
    withPython3 = false;
    withRuby = false;
    withNodeJs = false;
    withPerl = false;
    luaLoader.enable = true;
    imports = [
      ./plugins/autopairs.nix
      ./plugins/blink.nix
      ./plugins/colorscheme.nix
      ./plugins/colorizer.nix
      ./plugins/flash.nix
      ./plugins/gitsigns.nix
      ./plugins/hlchunk.nix
      ./plugins/key-menu.nix
      ./plugins/lspconfig.nix
      ./plugins/lspsaga.nix
      ./plugins/lualine.nix
      ./plugins/neoscroll.nix
      ./plugins/noice.nix
      ./plugins/oil.nix
      ./plugins/scrollbar.nix
      ./plugins/smear-cursor.nix
      ./plugins/telescope.nix
      ./plugins/treesitter.nix
      ./plugins/todo-comments.nix
      ./plugins/toggleterm.nix
      ./plugins/ts-autotag.nix
      ./plugins/vim-astro.nix
    ];
    plugins.web-devicons.enable = false;
    plugins.lz-n = {
      enable = true;
      autoLoad = true;
    };
    performance.byteCompileLua = {
      enable = true;
      nvimRuntime = true;
      initLua = true;
      configs = true;
      plugins = true;
    };
    globals = {
      mapleader = " ";
      maplocalleader = " ";
      loaded_netrw = 1;
      loaded_netrwPlugin = 1;
      loaded_netrwSettings = 1;
      loaded_netrwFileHandlers = 1;
      loaded_python3_provider = 0;
      loaded_node_provider = 0;
      loaded_perl_provider = 0;
      loaded_ruby_provider = 0;
    };
    opts = {
      clipboard = "unnamedplus";
      termguicolors = true;
      ttimeoutlen = 50;
      swapfile = false;
      wildmode = [ "list" "full" ];
      pumborder = "rounded";
      pumblend = 10;
      winblend = 10;
      number = true;
      showcmd = true;
      ignorecase = true;
      smartcase = true;
      wrap = true;
      linebreak = true;
      breakindent = true;
      signcolumn = "yes";
      expandtab = true;
      wildmenu = true;
      tabstop = 2;
      showtabline = 1;
      shiftwidth = 2;
      scrolloff = 5;
      winborder = "rounded";
      whichwrap = "b,s,h,l,<,>,[,],~";
      smartindent = true;
      showmatch = true;
      cursorline = true;
      cmdheight = 1;
      guicursor = "n-v:block,i:ver50,c:hor50,a:blinkon500-blinkoff500";
      updatetime = 300;
    };
    keymaps = [
      { mode = "n"; key = "<S-l>"; action = "<cmd>bnext<cr>"; options.desc = "Next buffer"; }
      { mode = "n"; key = "<S-h>"; action = "<cmd>bprevious<cr>"; options.desc = "Previous buffer"; }
      { mode = "n"; key = "U"; action = "<C-r>"; options = { noremap = true; silent = true; desc = "Redo"; }; }
      { mode = "n"; key = "Q"; action = "q"; options.desc = "Record macro"; }
      { mode = "n"; key = "q"; action = "<Nop>"; options.desc = "Disable accidental macro recording"; }
      { mode = [ "n" "x" ]; key = "x"; action = "\"_x"; options = { silent = true; desc = "Delete without yank"; }; }
      { mode = [ "n" "x" ]; key = "X"; action = "\"_X"; options = { silent = true; desc = "Delete without yank"; }; }
      { mode = "n"; key = "<A-h>"; action = "b"; options = { remap = true; silent = true; desc = "Prev word"; }; }
      { mode = "n"; key = "<A-l>"; action = "w"; options = { remap = true; silent = true; desc = "Next word"; }; }
      { mode = "n"; key = "<A-k>"; action = "<C-u>"; options = { remap = true; silent = true; desc = "Page up"; }; }
      { mode = "n"; key = "<A-j>"; action = "<C-d>"; options = { remap = true; silent = true; desc = "Page down"; }; }
      { mode = "n"; key = "<leader>rw"; action = "\"_diwP"; options.desc = "Replace word with yanked"; }
      { mode = "n"; key = "<leader>tc"; action = "g~iw"; options = { remap = false; desc = "Toggle word case"; }; }
      { mode = "i"; key = "<A-w>"; action = "<C-Right>"; options.desc = "Move words to right"; }
      { mode = "i"; key = "<A-b>"; action = "<C-Left>"; options.desc = "Move words to left"; }
      { mode = "i"; key = "<A-l>"; action = "<End>"; options.desc = "Move to end of line"; }
      { mode = "i"; key = "<A-h>"; action = "<Home>"; options.desc = "Move to start of line"; }
      { mode = "x"; key = "<"; action = "<gv"; options = { noremap = true; silent = true; desc = "Indent to left"; }; }
      { mode = "x"; key = ">"; action = ">gv"; options = { noremap = true; silent = true; desc = "Indent to right"; }; }
      { mode = "x"; key = "<A-j>"; action = ":m '>+1<CR>gv=gv"; options = { silent = true; desc = "Move line"; }; }
      { mode = "x"; key = "<A-k>"; action = ":m '<-2<CR>gv=gv"; options = { silent = true; desc = "Move line"; }; }
      { mode = "x"; key = "<leader>r"; action = "\"_dP"; options.desc = "Replace selection with yanked"; }
      { mode = "c"; key = "<c-a>"; action = "<home>"; options.desc = "Emacs like home"; }
      { mode = "c"; key = "<c-e>"; action = "<end>"; options.desc = "Emacs like end"; }
      { mode = "c"; key = "<M-b>"; action = "<S-Left>"; options.desc = "Word left in cmdline"; }
      { mode = "c"; key = "<M-f>"; action = "<S-Right>"; options.desc = "Word right in cmdline"; }
      { mode = "n"; key = "<leader>yd"; options.desc = "Yank diagnostic message"; action.__raw = ''
        function()
          local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
          if #diagnostics == 0 then
            vim.notify("No diagnostics", vim.log.levels.INFO)
            return
          end
          local messages = vim.tbl_map(function(d) return d.message end, diagnostics)
          local text = table.concat(messages, "\n")
          vim.fn.setreg("+", text)
          vim.notify("Yanked: " .. text)
        end
      ''; }
      { mode = "n"; key = "<Esc>"; options.desc = "Clear search highlight or escape"; action.__raw = ''
        function()
          if vim.v.hlsearch == 1 then
            vim.cmd.nohlsearch()
          else
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
          end
        end
      ''; }
    ];
    autoCmd = [
      { event = "BufEnter"; callback.__raw = ''
        function()
          local matches = vim.fn.getmatches()
          for _, m in ipairs(matches) do
            if m.pattern == "\\%u200b" then return end
          end
          vim.fn.matchadd("ErrorMsg", "\\%u200b")
        end
      ''; }
      { event = "CursorHold"; callback.__raw = ''
        function()
          vim.diagnostic.open_float(nil, {
            focus = false,
            scope = "cursor",
            close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
            border = "rounded",
            source = "if_many",
          })
        end
      ''; }
    ];
    extraFiles = {
      "snippets/html.json".source = ./snippets/html.json;
      "snippets/package.json".source = ./snippets/package.json;
    };
    extraConfigLua = ''
      local english_im = "com.apple.inputmethod.Kotoeri.RomajiTyping.Roman"
      vim.api.nvim_create_autocmd("ModeChanged", {
        group = vim.api.nvim_create_augroup("AutoSwitchIMOnNormal", { clear = true }),
        pattern = "*:n*",
        callback = function() vim.fn.system({ "macism", english_im }) end,
      })
    '';
  };
}
