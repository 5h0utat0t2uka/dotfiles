return {
  "romgrk/barbar.nvim",
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
      -- buffer_number = false,
      -- button = false,
      -- diagnostics = {
      --   [vim.diagnostic.severity.ERROR] = { enabled = false },
      --   [vim.diagnostic.severity.WARN]  = { enabled = false },
      --   [vim.diagnostic.severity.INFO]  = { enabled = false },
      --   [vim.diagnostic.severity.HINT]  = { enabled = false },
      -- },
    }
  },
  version = '^1.0.0',
}
