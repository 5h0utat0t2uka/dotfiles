{
  colorscheme = "nord";
  globals.nord_bold = true;
  colorschemes.nord = {
    enable = true;
    autoLoad = true;
    settings = {
      contrast = true;
      borders = true;
      disable_background = false;
      italic = false;
      uniform_diff_background = true;
    };
  };

  extraConfigLua = ''
    local function apply_custom_highlights()
      vim.api.nvim_set_hl(0, "CursorLine", { bg = "#353B49" })
      vim.api.nvim_set_hl(0, "Whitespace", { fg = "#434C5E" })
      vim.api.nvim_set_hl(0, "NonText", { fg = "#434C5E" })
      vim.api.nvim_set_hl(0, "ZenkakuSpace", { fg = "#BF616A" })
      vim.api.nvim_set_hl(0, "Visual", { bg = "#413F4C" })
      vim.api.nvim_set_hl(0, "TabLine", { fg = "#4C566A", bg = "#2E3440" })
      vim.api.nvim_set_hl(0, "TabLineSel", { fg = "#81A1C1", bg = "#2E3440", bold = true })
      vim.api.nvim_set_hl(0, "TabLineFill", { bg = "#2E3440" })
      vim.api.nvim_set_hl(0, "WinBar", { bg = "#2e3440", fg = "#4c566a" })
      vim.api.nvim_set_hl(0, "WinBarNC", { bg = "#2e3440", fg = "#4c566a" })
      vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#3b4252", bg = "NONE" })
      vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#4c566a", bg = "NONE" })
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "MsgArea", { fg = "#81A1C1", bg = "#2E3440" })
      vim.api.nvim_set_hl(0, "Pmenu", { bg = "#2E3440", fg = "#D8DEE9" })
      vim.api.nvim_set_hl(0, "BlinkCmpMenuBorder", { fg = "#4c566a", bg = "#2E3440" })
      vim.api.nvim_set_hl(0, "Search", { fg = "#2E3440", bg = "#81A1C1", bold = true })
      vim.api.nvim_set_hl(0, "CurSearch", { fg = "#2E3440", bg = "#D08770", bold = true })
      vim.api.nvim_set_hl(0, "IncSearch", { fg = "#2E3440", bg = "#81A1C1", bold = true })
      vim.api.nvim_set_hl(0, "ComplHint", { fg = "#4c566a" })
      vim.api.nvim_set_hl(0, "ComplHintMore", { fg = "#4c566a", italic = true })
      vim.api.nvim_set_hl(0, "TelescopeBorder", { fg = "#4C566A", bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopePromptBorder", { fg = "#5E81AC", bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopeResultsBorder", { fg = "#4C566A", bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopePreviewBorder", { fg = "#4C566A", bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopePromptTitle", { fg = "#5E81AC", bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopePromptNormal", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopeResultsNormal", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopePreviewNormal", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopeSelection", { fg = "NONE", bg = "#3B4252", bold = true })
      vim.api.nvim_set_hl(0, "TelescopeMatching", { fg = "#81A1C1", bg = "NONE", bold = true })
      vim.api.nvim_set_hl(0, "NotifyINFOBorder", { fg = "#5E81AC" })
      vim.api.nvim_set_hl(0, "NotifyERRORBorder", { fg = "#BF616A" })
      vim.api.nvim_set_hl(0, "NotifyWARNBorder", { fg = "#B48EAD" })
      vim.api.nvim_set_hl(0, "NotifyINFOIcon", { fg = "#5E81AC" })
      vim.api.nvim_set_hl(0, "NotifyERRORIcon", { fg = "#BF616A" })
      vim.api.nvim_set_hl(0, "NotifyWARNIcon", { fg = "#B48EAD" })
      vim.api.nvim_set_hl(0, "NotifyINFOTitle", { fg = "#5E81AC" })
      vim.api.nvim_set_hl(0, "NotifyERRORTitle", { fg = "#BF616A" })
      vim.api.nvim_set_hl(0, "NotifyWARNTitle", { fg = "#B48EAD" })
    end

    apply_custom_highlights()

    local group = vim.api.nvim_create_augroup("NordOverrides", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = group,
      callback = apply_custom_highlights,
    })

    vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave" }, {
      group = group,
      callback = function(e)
        local bg = e.event == "InsertEnter" and "#2E3440" or "#353B49"
        vim.api.nvim_set_hl(0, "CursorLine", { bg = bg })
      end,
    })
    vim.api.nvim_create_autocmd({ "VimEnter", "BufReadPost" }, {
      callback = function()
        vim.fn.matchadd("ZenkakuSpace", "　")
      end,
    })
  '';
}
