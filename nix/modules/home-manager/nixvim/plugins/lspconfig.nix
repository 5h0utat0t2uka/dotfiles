{ pkgs, lib, ... }:

{
  plugins.lspconfig = {
    enable = true;
  };
  plugins.lazydev = {
    enable = true;
    lazyLoad.settings = {
      ft = "lua";
    };
    settings = { };
  };
  lsp.servers = {
    "*".config = {
      capabilities = lib.nixvim.mkRaw ''require("blink.cmp").get_lsp_capabilities()'';
    };
    lua_ls = {
      enable = true;
      config = {
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
    };
    nixd = {
      enable = true;
      config.settings.nixd.formatting.command = [ "nixfmt" ];
    };

    # FIXME: issue: lsp.progress notification on every keystroke (https://github.com/microsoft/pyright/issues/11408?utm_source=chatgpt.com)
    pyright = {
      enable = true;
      config.settings.python.analysis = {
        typeCheckingMode = "basic";
        autoSearchPaths = true;
        useLibraryCodeForTypes = true;
      };
    };
    eslint = {
      enable = true;
    };
    html = {
      enable = true;
    };
    cssls = {
      enable = true;
    };
    ts_ls = {
      enable = true;
      config.root_dir = lib.nixvim.mkRaw ''
        function(bufnr, on_dir)
          local root = vim.fs.root(bufnr, {
            "tsconfig.json",
            "jsconfig.json",
            "package.json",
            ".git",
          })
          if root then
            on_dir(root)
            return
          end
          local name = vim.api.nvim_buf_get_name(bufnr)
          local dir = vim.fs.dirname(name)
          if dir and dir ~= "" then
            on_dir(dir)
          end
        end
      '';
    };

    # FIXME: issue: language-server crashes on attach #16612 (https://github.com/withastro/astro/issues/16612?utm_source=chatgpt.com)
    astro = {
      enable = true;
      package = pkgs.astro-language-server;
      config = {
        cmd_env = {
          NODE_PATH = "${pkgs.typescript}/lib/node_modules";
        };
        init_options = {
          typescript = {
            tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
          };
        };
      };
    };
    # astro = {
    #   enable = true;
    #   config = {
    #     init_options = {
    #       typescript = {
    #         tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
    #       };
    #     };
    #   };
    # };
  };
  extraConfigLua = ''
    pcall(vim.lsp.enable, "copilot")
    vim.lsp.inline_completion.enable(true)
    vim.keymap.set("i", "<M-CR>", function()
      vim.lsp.inline_completion.get()
    end, { silent = true, desc = "Copilot inline completion" })
  '';
}
