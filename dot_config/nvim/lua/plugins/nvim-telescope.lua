return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    cmd = "Telescope",
    keys = function()
      local b = function(fn, opts)
        return function() require("telescope.builtin")[fn](opts) end
      end
      return {
        { "<leader>ff", b("find_files", { hidden = true }), desc = "Find files" },
        { "<leader>fg", b("live_grep"),                     desc = "Live grep" },
        { "<leader>fb", b("buffers"),                       desc = "Buffers" },
        { "<leader>gs", b("git_status"),                    desc = "Git status" },
        { "<leader>gc", b("git_commits"),                   desc = "Git commits" },
        { "<leader>gb", b("git_branches"),                  desc = "Git branches" },
        { "<leader>fh", b("help_tags"),                     desc = "Help tags" },
      }
    end,
    opts = {
      defaults = {
        border = true,
        winblend = 10,
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
