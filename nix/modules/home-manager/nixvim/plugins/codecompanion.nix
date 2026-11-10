# codecompanion.nix
{ ... }:

{
  keymaps = [
    {
      mode = "x";
      key = "<leader>ar";
      action.__raw = ''
        function()
          local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
          vim.api.nvim_feedkeys(esc, "nx", false)
          vim.schedule(function()
            vim.cmd([['<,'>CodeCompanion Refactor the selected code. Keep the existing behavior unchanged. Improve readability, type-safety, and maintainability.]])
          end)
        end
      '';
      options = {
        silent = true;
        desc = "AI refactor selection";
      };
    }
    {
      mode = "x";
      key = "<leader>af";
      action.__raw = ''
        function()
          local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
          vim.api.nvim_feedkeys(esc, "nx", false)
          vim.schedule(function()
            vim.cmd([['<,'>CodeCompanion /fix]])
          end)
        end
      '';
      options = {
        silent = true;
        desc = "AI fix selection";
      };
    }
    {
      mode = "x";
      key = "<leader>ae";
      action.__raw = ''
        function()
          local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
          vim.api.nvim_feedkeys(esc, "nx", false)
          vim.schedule(function()
            vim.cmd([['<,'>CodeCompanion #{diagnostics} Fix the diagnostics related to the selected code. Replace the selected code with the corrected code.]])
          end)
        end
      '';
      options = {
        silent = true;
        desc = "AI fix selected diagnostics";
      };
    }
  ];
  plugins.codecompanion = {
    enable = true;
    lazyLoad.settings = {
      cmd = [
        "CodeCompanion"
        "CodeCompanionChat"
        "CodeCompanionActions"
        "CodeCompanionCmd"
      ];
      keys = [
        {
          __unkeyed-1 = "<leader>aa";
          mode = [
            "n"
            "x"
          ];
          __unkeyed-2 = "<cmd>CodeCompanionActions<CR>";
          desc = "AI actions";
        }
      ];
    };
    settings = {
      adapters = {
        http = {
          anthropic = {
            __raw = ''
              function()
                return require("codecompanion.adapters").extend("anthropic", {
                  env = {
                    api_key = "API_KEY",
                  },
                  schema = {
                    model = {
                      default = "claude-sonnet-4-6",
                    },
                    extended_thinking = {
                      default = false,
                    },
                  },
                })
              end
            '';
          };
          anthropic_inline = {
            __raw = ''
              function()
                return require("codecompanion.adapters").extend("anthropic", {
                  env = {
                    api_key = "API_KEY",
                  },
                  opts = {
                    compaction = false,
                    tools = false,
                  },
                  schema = {
                    model = {
                      default = "claude-haiku-4-5",
                    },
                    extended_thinking = {
                      default = false,
                    },
                    temperature = {
                      default = 0,
                    },
                  },
                })
              end
            '';
          };
        };
      };
      interactions = {
        chat = {
          adapter = "anthropic";
        };
        inline = {
          adapter = "anthropic_inline";
        };
        cmd = {
          adapter = "anthropic_inline";
        };
      };
      display = {
        action_palette = {
          provider = "telescope";
        };
        inline = {
          layout = "buffer";
        };
      };
      opts = {
        log_level = "ERROR";
      };
    };
  };
}
