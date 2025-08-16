return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  opts = {
    indent = {
      -- char = "│",
      char = "▏",
      highlight = { "IblIndent" },
    },
    scope = {
      enabled = true,
      show_start = true,
      show_end = true,
      highlight = { "IblScope" },
    },
  },
}
