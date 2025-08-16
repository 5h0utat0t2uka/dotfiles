return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local custom = vim.deepcopy(require("lualine.themes.nord"))
    local colors = {
      normal   = "#81a1c1",
      insert   = "#a3be8c",
      visual   = "#b48ead",
      replace  = "#d08770",
      command  = "#bf616a",
      inactive = "#2E3440",
    }
    for mode, sections in pairs(custom) do
      if sections.c then
        sections.c.bg = colors.inactive
      end
      local color = colors[mode] or colors.normal
      if sections.a then sections.a.bg = color end
      if sections.z then sections.z.bg = color end
    end

    require("lualine").setup({
      options = {
        theme = custom,
        section_separators = {
          left = "▓░",
          right = "░▓",
        },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { { "branch", icon = "" }, "diff" },
        lualine_c = { "filename" },
        lualine_x = {},
        lualine_y = {},
        lualine_z = { "location" },
      },
    })
  end,
}
