return {
  "shaunsingh/nord.nvim",
  lazy=false,
  priority = 1000,
  config = function()
    vim.g.nord_contrast = true
    vim.g.nord_borders = true
    vim.g.nord_disable_background = false
    vim.g.nord_italic = false
    vim.g.nord_uniform_diff_background = true
    vim.g.nord_bold = true
    vim.cmd.colorscheme("nord")

    vim.api.nvim_set_hl(0, "IblIndent", { fg = "#3b4252" })
    vim.api.nvim_set_hl(0, "IblScope",  { fg = "#4c566a" })
  end,
}
