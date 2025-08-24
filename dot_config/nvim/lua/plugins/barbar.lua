return {
  "romgrk/barbar.nvim",
  enabled = false,

  dependencies = {
    'lewis6991/gitsigns.nvim',
  },
  init = function() vim.g.barbar_auto_setup = false end,
  opts = {
    -- lazy.nvim will automatically call setup for you. put your options here, anything missing will use the default:
    -- animation = true,
    -- insert_at_start = true,
    -- …etc.
    icons = {
      filetype = {
        enabled = false,
      },
      separator = {left = '', right = ''},
      separator_at_end = false,
    }
  },
  version = '^1.0.0',
}
