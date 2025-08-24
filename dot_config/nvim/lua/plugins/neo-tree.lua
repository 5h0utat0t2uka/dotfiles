return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons", -- optional, but recommended
    },
    keys = {
      {
        "<leader>e",
        "<cmd>Neotree toggle<cr>",
        desc = "NeoTree toggle (left)",
      }
    },
    opts = {
      default_component_configs = {
        root = {
          symbol = ""
        },
        indent = {
          padding = 0
        },
      },
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          never_show = {
            ".DS_Store",
          },
        },
      },
    },
    config = function(_, opts)
      require("neo-tree").setup(opts)
      -- vim.api.nvim_set_hl(0, "NeoTreeWinSeparator", { fg = "#4c566a", bg = "NONE" })
    end,
  }
}
