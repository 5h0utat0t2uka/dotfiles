# nix/modules/home-manager/nixvim/plugins/todo-comments.nix
{ ... }:

{
  plugins.todo-comments = {
    enable = true;
    lazyLoad.settings = {
      event = "BufReadPost";
      cmd = [
        "TodoQuickFix"
        "TodoLocList"
      ];
    };
    settings = {
      signs = false;
      keywords = {
        FIX = {
          icon = "";
          color = "error";
          alt = [
            "FIXME"
            "BUG"
            "FIXIT"
            "ISSUE"
          ];
        };
        TODO = {
          icon = "";
          color = "hint";
        };
        HACK = {
          icon = "";
          color = "warning";
        };
        WARN = {
          icon = "";
          color = "warning";
          alt = [
            "WARNING"
            "XXX"
          ];
        };
        PERF = {
          icon = "";
          color = "default";
          alt = [
            "OPTIM"
            "PERFORMANCE"
            "OPTIMIZE"
          ];
        };
        NOTE = {
          icon = "";
          color = "info";
          alt = [ "INFO" ];
        };
        TEST = {
          icon = "";
          color = "test";
          alt = [
            "TESTING"
            "PASSED"
            "FAILED"
          ];
        };
      };
      highlight = {
        keyword = "wide";
        after = "fg";
      };
      colors = {
        error = [ "#7A3D43" ]; # #BF616A
        warning = [ "#855040" ]; # #D08770
        info = [ "#4C6478" ]; # #81A1C1
        hint = [ "#4C6478" ]; # #A3BE8C
        default = [ "#4C6478" ]; # #B48EAD
        test = [ "#9A7E4A" ]; # #EBCB8B
      };
    };
  };

  extraConfigLua = ''
    local function darken_hex(hex)
      hex = hex:gsub("#", "")
      return string.format("#%02x%02x%02x",
        math.floor(tonumber(hex:sub(1, 2), 16) / 1.4),
        math.floor(tonumber(hex:sub(3, 4), 16) / 1.4),
        math.floor(tonumber(hex:sub(5, 6), 16) / 1.4))
    end
    local function lighten_hex(hex)
      hex = hex:gsub("#", "")
      return string.format("#%02x%02x%02x",
        math.floor(tonumber(hex:sub(1, 2), 16) * 1.5),
        math.floor(tonumber(hex:sub(3, 4), 16) * 1.5),
        math.floor(tonumber(hex:sub(5, 6), 16) * 1.5))
    end
    local todo_colors = {
      FIX = "#7A3D43",
      TODO = "#4C6478",
      HACK = "#855040",
      WARN = "#855040",
      PERF = "#4C6478",
      NOTE = "#4C6478",
      TEST = "#9A7E4A",
    }
    local function apply_todo_highlights()
      for keyword, hex in pairs(todo_colors) do
        vim.api.nvim_set_hl(0, "TodoBg" .. keyword, {
          fg = lighten_hex(hex),
          bg = hex,
          bold = true,
        })
        vim.api.nvim_set_hl(0, "TodoFg" .. keyword, {
          fg = hex,
          bg = "NONE",
        })
        vim.api.nvim_set_hl(0, "TodoSign" .. keyword, {
          fg = hex,
          bg = "NONE",
        })
      end
    end
    apply_todo_highlights()

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("TodoCommentsOverrides", { clear = true }),
      callback = function()
        vim.defer_fn(apply_todo_highlights, 20)
      end,
    })
  '';
}
