return {
  "luukvbaal/statuscol.nvim",
  event = "VeryLazy",
  opts = function()
    local builtin = require("statuscol.builtin")
    return {
      setopt = true,
      relculright = true,
      segments = {
        -- { text = { "~ " } },
        { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
        -- Diagnostics
        {
          sign = {
            name = { "Diagnostic" },
            maxwidth = 2,
            colwidth = 1,
            auto = true,
            wrap = true,
          },
          click = "v:lua.ScSa",
        },
        -- GitSigns
        {
          sign = {
            name = { "GitSigns" },
            maxwidth = 1,
            colwidth = 1,
            auto = true,
            fillchar = " ",
          },
          click = "v:lua.ScSa",
        },
        { text = { builtin.lnumfunc, " " }, click = "v:lua.ScLa" },
      },
    }
  end,
}
