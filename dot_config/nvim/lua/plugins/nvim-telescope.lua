return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = {
          width = 0.90,
          height = 0.90,
          preview_width = 0.5,
          prompt_position = "bottom",
        },
        file_ignore_patterns = {
          "^.git/",
          "^.cache/",
          "^.zsh_sessions/",
          "node_modules/",
          "Library/",
          "Movies/",
          "Pictures/",
          "Music/",
          ".DS_Store",
        },
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "-uu",
          "--hidden",
        }
      },
    }
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    config = function()
      require("telescope").load_extension("fzf")
    end
  }
}
