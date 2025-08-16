return {
  {
    'luukvbaal/statuscol.nvim',
    event = 'BufReadPre',
    config = function()
      local builtin = require('statuscol.builtin')
      require('statuscol').setup({
        bt_ignore = { 'terminal', 'nofile', 'ddu-ff', 'ddu-ff-filter' },

        relculright = true,
        segments = {
          {
            sign = {
              namespace = { 'diagnostic/signs' },
              maxwidth = 1,
            },
          },
          {
            sign = {
              namespace = { 'gitsigns' },
              maxwidth = 1,
              colwidth = 1,
              wrap = true,
              fillchar = " ",
            },
          },
          { text = { builtin.lnumfunc, " " }, click = "v:lua.ScLa" },
          { text = { '  ' } },
        },
      })
    end,
  },
}

-- return {
--   "luukvbaal/statuscol.nvim",
--   event = "VeryLazy",
--   opts = function()
--     local builtin = require("statuscol.builtin")
--     return {
--       setopt = true,
--       relculright = true,
--       segments = {
--         { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
--         {
--           sign = {
--             name = { "Diagnostic" },
--             maxwidth = 2,
--             colwidth = 1,
--             auto = true,
--             wrap = false,
--           },
--           click = "v:lua.ScSa",
--         },
--         {
--           sign = {
--             namespace = { "gitsigns" },
--             maxwidth = 1,
--             colwidth = 1,
--             auto = true,
--             wrap = false,
--             fillchar = " ",
--           },
--           click = "v:lua.ScSa",
--         },
--         { text = { builtin.lnumfunc, " " }, click = "v:lua.ScLa" },
--       },
--     }
--   end,
-- }
