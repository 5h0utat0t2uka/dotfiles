return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    cmdline = {
      enabled = true, -- enables the Noice cmdline UI
      view = "cmdline_popup", -- view for rendering the cmdline. Change to `cmdline` to get a classic cmdline at the bottom
      opts = {}, -- global options for the cmdline. See section on views
      ---@type table<string, CmdlineFormat>
      format = {
        -- conceal: (default=true) This will hide the text in the cmdline that matches the pattern.
        -- view: (default is cmdline view)
        -- opts: any options passed to the view
        -- icon_hl_group: optional hl_group for the icon
        -- title: set to anything or empty string to hide
        cmdline = { pattern = "^:", icon = "", lang = "vim" },
        search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
        search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
        filter = { pattern = "^:%s*!", icon = "$", lang = "bash" },
        lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
        help = { pattern = "^:%s*he?l?p?%s+", icon = "" },
        input = { view = "cmdline_input", icon = "󰥻 " }, -- Used by input()
        -- lua = false, -- to disable a format, set to `false`
      },
    },
    views = {
      cmdline_popup = {
        position = { row = "50%", col = "50%" }, -- 例: 画面中央
        size = {
          width = 80,        -- 固定幅（"auto" も可）
          height = "auto",   -- 入力に応じて自動高さ
          min_width = 40,    -- 任意
          max_width = 80,    -- 任意
        },
        border = {
          style = "rounded",
          padding = { 1, 1 },
          text = {
            top = "",
            top_align = "center",
          }
        },
        -- border = {
        --   style = "none",
        --   padding = { 1, 2 },
        -- },
        filter_options = {},
        win_options = {
          winhighlight = { Normal = "Normal", FloatBorder = "NoiceCmdlinePopupBorder" },
          -- winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
        },
      }
    }
  },
  dependencies = {
    -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
    "MunifTanjim/nui.nvim",
    -- OPTIONAL:
    --   `nvim-notify` is only needed, if you want to use the notification view.
    --   If not available, we use `mini` as the fallback
    "rcarriga/nvim-notify",
  }
}
