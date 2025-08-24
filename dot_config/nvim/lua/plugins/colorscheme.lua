return {
  "shaunsingh/nord.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    vim.g.nord_contrast = true
    vim.g.nord_borders = true
    vim.g.nord_disable_background = false
    vim.g.nord_italic = false
    vim.g.nord_uniform_diff_background = true
    vim.g.nord_bold = true

    vim.cmd.colorscheme("nord")
    vim.api.nvim_set_hl(0, "WinBar", { bg = "#2e3440", fg = "#4c566a" })
    vim.api.nvim_set_hl(0, "WinBarNC", { bg = "#2e3440", fg = "#4c566a" })

    -- indent-blankline
    -- vim.api.nvim_set_hl(0, "IblIndent", { fg = "#3b4252" })
    -- vim.api.nvim_set_hl(0, "IblScope",  { fg = "#4c566a" })

    -- neo-tree
    local function set_neotree_hl()
      vim.api.nvim_set_hl(0, "NeoTreeWinSeparator", { fg = "#3b4252", bg = "none" })
    end
    set_neotree_hl()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("MyNeoTreeHl", { clear = true }),
      callback = set_neotree_hl,
    })

    -- telescope
    local function set_telescope_hl()
      vim.api.nvim_set_hl(0, "TelescopeBorder",        { fg = "#d8dee9", bg = "none" })
      vim.api.nvim_set_hl(0, "TelescopePromptBorder",  { fg = "#d8dee9", bg = "none" })
      vim.api.nvim_set_hl(0, "TelescopeResultsBorder", { fg = "#d8dee9", bg = "none" })
      vim.api.nvim_set_hl(0, "TelescopePreviewBorder", { fg = "#d8dee9", bg = "none" })
    end
    set_telescope_hl()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("MyTelescopeHl", { clear = true }),
      callback = set_telescope_hl,
    })
  end,
}
