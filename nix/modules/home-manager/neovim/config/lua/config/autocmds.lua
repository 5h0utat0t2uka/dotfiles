-- ~/.config/nvim/lua/config/autocmds.lua

vim.o.updatetime = 300
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    local matches = vim.fn.getmatches()
    for _, m in ipairs(matches) do
      if m.pattern == "\\%u200b" then
        return
      end
    end
    vim.fn.matchadd("ErrorMsg", "\\%u200b")
  end,
})
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, {
      focus = false,
      scope = "cursor",
      close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
      border = "rounded",
      source = "if_many",
    })
  end,
})
