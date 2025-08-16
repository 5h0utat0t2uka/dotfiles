return {
  {
    "nvimdev/dashboard-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local stats = require("lazy").stats()

      require("dashboard").setup({
        theme = "doom",
        config = {
          header = {
            [[  @@@  @@@  @@@@@@@@   @@@@@@   @@@  @@@  @@@  @@@@@@@@@@   ]],
            [[  @@@@ @@@  @@@@@@@@  @@@@@@@@  @@@  @@@  @@@  @@@@@@@@@@@  ]],
            [[  @@!@!@@@  @@!       @@!  @@@  @@!  @@@  @@!  @@! @@! @@!  ]],
            [[  !@!!@!@!  !@!       !@!  @!@  !@!  @!@  !@!  !@! !@! !@!  ]],
            [[  @!@ !!@!  @!!!:!    @!@  !@!  @!@  !@!  !!@  @!! !!@ @!@  ]],
            [[  !@!  !!!  !!!!!:    !@!  !!!  !@!  !!!  !!!  !@!  :! !@!  ]],
            [[  !!:  !!!  !!:       !!:  !!!  :!:  !!:  !!:  !!:  :  !!:  ]],
            [[  :!:  !:!  :!:       :!:  !:!   ::!!:!   :!:  :!:     :!:  ]],
            [[  ::   ::   :: ::::   ::::: ::    ::::    ::   ::      ::   ]],
            [[  ::    :   : :: ::    : :  :       :      :    :       :   ]],
            [[                                                            ]],
            [[                                                            ]],
            [[                                                            ]],
            [[                                                            ]],
            [[                                                            ]],
          },
          center = {
            {
              icon = " ",
              desc = "recent",
              key = "R",
              action = "Telescope oldfiles"
            },
            {
              icon = " ",
              desc = "quit",
              key = "Q",
              action = function() vim.cmd("qa") end
            }
          },
          footer = {
            "",
            "",
            "",
            "",
            "",
            "",
            ("Loaded %d plugins"):format(stats.loaded),
          },
          vertical_center = true
        },
      })

      vim.api.nvim_set_hl(0, "DashboardHeader", { fg = "#5e81ac", bold = true })
      -- vim.api.nvim_set_hl(0, "DashboardDesc", { fg = "#4c566a" })
      vim.api.nvim_set_hl(0, "DashboardFooter", { fg = "#b48ead", italic = false })
    end,
  }
}
