{ pkgs, lib, ... }:

{
  plugins.lsp = {
    enable = true;
    servers = {
      lua_ls = {
        enable = true;
        settings = {
          Lua = {
            workspace = {
              checkThirdParty = false;
              library = [
                (lib.nixvim.mkRaw "vim.env.VIMRUNTIME")
                (lib.nixvim.mkRaw "vim.env.VIMRUNTIME .. '/lua'")
              ];
            };
            diagnostics.globals = [ "vim" ];
            telemetry.enable = false;
          };
        };
      };

      nixd = {
        enable = true;
        settings.nixd.formatting.command = [ "nixfmt" ];
      };

      pyright = {
        enable = true;
        settings.python.analysis = {
          typeCheckingMode = "basic";
          autoSearchPaths = true;
          useLibraryCodeForTypes = true;
        };
      };

      tofu_ls = {
        enable = true;
      };

      eslint = {
        enable = true;
        package = null;
      };

      jsonls = {
        enable = true;
        package = null;
      };

      html = {
        enable = true;
        package = null;
      };

      cssls = {
        enable = true;
        package = null;
      };

      ts_ls = {
        enable = true;
        filetypes = lib.mkForce [
          "javascript"
          "javascriptreact"
          "typescript"
          "typescriptreact"
        ];
        rootMarkers = [
          "tsconfig.json"
          "jsconfig.json"
          "package.json"
          ".git"
        ];
      };

      astro = {
        enable = true;
        extraOptions = {
          init_options = {
            typescript = {
              tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
            };
          };
        };
      };
    };
  };

  plugins.lazydev = {
    enable = true;
    lazyLoad.settings.ft = "lua";
    settings = { };
  };

  extraConfigLuaPre = ''
    vim.lsp.config("*", {
      capabilities = require("blink.cmp").get_lsp_capabilities(),
    })
  '';

  extraConfigLua = ''
    vim.filetype.add({
      extension = {
        tofu = "opentofu",
        tfvars = "opentofu-vars",
      },
    })

    pcall(vim.lsp.enable, "copilot")
    vim.lsp.inline_completion.enable(true)
    vim.keymap.set("i", "<M-CR>", function()
      vim.lsp.inline_completion.get()
    end, { silent = true, desc = "Copilot inline completion" })
  '';
}
