vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- vim.cmd.syntax("on")
vim.opt.termguicolors = true
vim.opt.ttimeoutlen = 50
-- vim.opt.backup = false
vim.opt.swapfile = false
-- vim.opt.showcmdloc = true
vim.opt.wildmode = { "list", "full" }
vim.opt.number = true
-- vim.opt.autoindent = true
-- vim.opt.mouse = "a"
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.showmatch = true
vim.opt.cursorline = true
-- vim.opt.ruler = true
-- vim.opt.wrap = true

-- lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- 安定版に固定
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
vim.opt.termguicolors = true

-- プラグイン
require("lazy").setup({
  {
    -- カラースキーム
    "shaunsingh/nord.nvim",
    priority = 1000,
    config = function()
      vim.g.nord_contrast = true
      vim.g.nord_borders = true
      vim.g.nord_disable_background = false
      vim.g.nord_italic = false
      vim.g.nord_uniform_diff_background = true
      vim.g.nord_bold = true
      vim.cmd.colorscheme("nord")
    end,
  },
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      -- local nord = require("lualine.themes.nord")
      local custom = vim.deepcopy(require("lualine.themes.nord"))
      local colors = {
        normal   = "#81a1c1",
        insert   = "#a3be8c",
        visual   = "#b48ead",
        replace  = "#d08770",
        command  = "#bf616a",
        inactive = "#2E3440",
      }
      local bg = "#2E3440"
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
  },
}, {
  lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
})
