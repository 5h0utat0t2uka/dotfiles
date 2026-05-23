{ pkgs, ... }:

let
  undo-glow-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "undo-glow.nvim";
    version = "1.13.0";
    src = pkgs.fetchFromGitHub {
      owner = "y3owk1n";
      repo = "undo-glow.nvim";
      rev = "ac70916caa2f4e57419bb4c1a2e303cdb7bb57e2";
      hash = "";
    };

    # src = builtins.fetchGit {
    #   url = "https://github.com/y3owk1n/undo-glow.nvim.git";
    #   rev = "ac70916caa2f4e57419bb4c1a2e303cdb7bb57e2";
    # };
  };
in
{
  extraPlugins = [{
    plugin = undo-glow-nvim;
    optional = true;
  }];
  plugins.lz-n.plugins = [
    {
      __unkeyed-1 = "undo-glow.nvim";
      event = "TextYankPost";
      keys = [
        {
          __unkeyed-1 = "u";
          mode = "n";
          __unkeyed-2.__raw = ''function() require("undo-glow").undo({ hl_color = { bg = "#4C566A" } }) end'';
          desc = "Undo with highlight";
        }
        {
          __unkeyed-1 = "U";
          mode = "n";
          __unkeyed-2.__raw = ''function() require("undo-glow").redo({ hl_color = { bg = "#4C566A" } }) end'';
          desc = "Redo with highlight";
        }
        {
          __unkeyed-1 = "p";
          mode = "n";
          __unkeyed-2.__raw = ''function() require("undo-glow").paste_below({ hl_color = { bg = "#6e596d" } }) end'';
          desc = "Paste below with highlight";
        }
        {
          __unkeyed-1 = "P";
          mode = "n";
          __unkeyed-2.__raw = ''function() require("undo-glow").paste_above({ hl_color = { bg = "#6e596d" } }) end'';
          desc = "Paste above with highlight";
        }
        {
          __unkeyed-1 = "gc";
          mode = [ "n" "x" ];
          __unkeyed-2.__raw = ''
            function()
              local pos = vim.fn.getpos(".")
              vim.schedule(function() vim.fn.setpos(".", pos) end)
              return require("undo-glow").comment({ hl_color = { bg = "#4C566A" } })
            end
          '';
          desc = "Toggle comment with highlight";
          expr = true;
        }
        {
          __unkeyed-1 = "gc";
          mode = "o";
          __unkeyed-2.__raw = ''function() require("undo-glow").comment_textobject({ hl_color = { bg = "#4C566A" } }) end'';
          desc = "Comment textobject with highlight";
        }
        {
          __unkeyed-1 = "gcc";
          mode = "n";
          __unkeyed-2.__raw = ''function() return require("undo-glow").comment_line({ hl_color = { bg = "#4C566A" } }) end'';
          desc = "Toggle comment line with highlight";
          expr = true;
        }
      ];
      after = ''
        function()
          local undo_glow_colors = {
            undo    = { bg = "#4C566A" },
            redo    = { bg = "#4C566A" },
            yank    = { bg = "#6e596d" },
            paste   = { bg = "#6e596d" },
            comment = { bg = "#4C566A" },
            search  = { bg = "#4C566A" },
          }

          require("undo-glow").setup({
            animation = {
              enabled = true,
              duration = 300,
              animation_type = "fade",
              window_scoped = true,
            },
            highlights = {
              undo    = { hl_color = undo_glow_colors.undo },
              redo    = { hl_color = undo_glow_colors.redo },
              yank    = { hl_color = undo_glow_colors.yank },
              paste   = { hl_color = undo_glow_colors.paste },
              comment = { hl_color = undo_glow_colors.comment },
              search  = { hl_color = undo_glow_colors.search },
            },
            priority = 2048 * 3,
          })

          local function apply_undo_glow_highlights()
            vim.api.nvim_set_hl(0, "UgUndo",    { bg = undo_glow_colors.undo.bg })
            vim.api.nvim_set_hl(0, "UgRedo",    { bg = undo_glow_colors.redo.bg })
            vim.api.nvim_set_hl(0, "UgYank",    { bg = undo_glow_colors.yank.bg })
            vim.api.nvim_set_hl(0, "UgPaste",   { bg = undo_glow_colors.paste.bg })
            vim.api.nvim_set_hl(0, "UgComment", { bg = undo_glow_colors.comment.bg })
            vim.api.nvim_set_hl(0, "UgSearch",  { bg = undo_glow_colors.search.bg })
          end

          apply_undo_glow_highlights()

          vim.api.nvim_create_autocmd("ColorScheme", {
            group = vim.api.nvim_create_augroup("UndoGlowHighlights", { clear = true }),
            callback = apply_undo_glow_highlights,
          })

          vim.api.nvim_create_autocmd("TextYankPost", {
            group = vim.api.nvim_create_augroup("UndoGlowYank", { clear = true }),
            desc = "Highlight when yanking text",
            callback = function()
              if vim.v.event.operator == "y" then
                require("undo-glow").yank({ hl_color = { bg = "#6e596d" } })
              end
            end,
          })
        end
      '';
    }
  ];
}
