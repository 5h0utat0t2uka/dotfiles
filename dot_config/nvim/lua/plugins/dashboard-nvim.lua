return {
  {
    "nvimdev/dashboard-nvim",
    init = function()
      local uv = vim.uv or vim.loop
      vim.g.__nvim_start_hrtime = uv.hrtime()
    end,

    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local function footer_text()
        local stats = require("lazy").stats()
        local ms = stats.startuptime and stats.startuptime > 0 and stats.startuptime
        local v = vim.version()
        if not ms then
          local uv = vim.uv or vim.loop
          local dt_ns = uv.hrtime() - (vim.g.__nvim_start_hrtime or uv.hrtime())
          ms = math.floor(dt_ns / 1e6 + 0.5)
        else
          ms = math.floor(ms + 0.5)
        end
        return ("Loaded %d plugins (%dms)"):format(stats.loaded, ms)
      end
      local function nvim_version()
        local v = vim.version()
        return ("NVIM v%d.%d.%d"):format(v.major, v.minor, v.patch)
      end

      local function make_footer()
        return { "", "", "", "", footer_text(), nvim_version() }
      end

      require("dashboard").setup({
        theme = "doom",
        config = {
          header = {
            [[                                                            ]],
            [[                                                            ]],
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
          },
          center = {
            {
              icon = " ",
              desc = "Recent files",
              key = "R",
              action = "Telescope oldfiles"
            },
            {
              icon = " ",
              desc = "New file",
              key  = "N",
              action = function()
                local dbuf = vim.api.nvim_get_current_buf()
                vim.cmd("enew")
                vim.cmd("startinsert")
                vim.schedule(function()
                  if vim.api.nvim_buf_is_valid(dbuf) then
                    pcall(vim.api.nvim_buf_delete, dbuf, { force = true })
                  end
                end)
              end,
            },
            {
              icon = " ",
              desc = "Quit nvim",
              key = "Q",
              action = function() vim.cmd("qa") end
            },
            -- {
            --   icon = " ",
            --   desc = "Seek help",
            --   key = "H",
            --   action = function()
            --     local dbuf = vim.api.nvim_get_current_buf()
            --     require("telescope.builtin").help_tags()
            --     vim.schedule(function()
            --       if vim.api.nvim_buf_is_valid(dbuf) then
            --         pcall(vim.api.nvim_buf_delete, dbuf, { force = true })
            --       end
            --     end)
            --   end,
            -- },
          },
          footer = make_footer(),
          vertical_center = true,
        },
      })

      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          if vim.fn.exists(":DashboardUpdateFooter") == 2 then
            require("dashboard").setup({ theme = "doom", config = { footer = make_footer() } })
            vim.cmd("DashboardUpdateFooter")
          end
        end,
      })
      vim.api.nvim_set_hl(0, "DashboardHeader", { fg = "#81a1c1", bold = true })
      vim.api.nvim_set_hl(0, "DashboardFooter", { fg = "#4c566a", bold = false })
    end,
  }
}
