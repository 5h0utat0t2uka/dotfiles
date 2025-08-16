return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  opts = {
    indent = {
      char = "│",
    },
    scope = {
      enabled = true,
      show_start = true,
      show_end = true,
    },
  },
  config = function(_, opts)
    -- デフォルトのセットアップ
    require("ibl").setup(opts)

    -- ハイライトを赤に変更
    vim.api.nvim_set_hl(0, "IblIndent", { fg = "#ff0000" })
    vim.api.nvim_set_hl(0, "IblScope", { fg = "#ff5555" })
  end,
}
