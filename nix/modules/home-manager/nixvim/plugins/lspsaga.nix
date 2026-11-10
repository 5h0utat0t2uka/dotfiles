{ ... }:

{
  plugins.lspsaga = {
    enable = true;
    lazyLoad.settings = {
      cmd = "Lspsaga";
      keys = [
        {
          __unkeyed-1 = "<Leader>lf";
          __unkeyed-2 = "<cmd>Lspsaga finder<CR>";
          desc = "LspSaga Finder";
        }
        {
          __unkeyed-1 = "<Leader>ld";
          __unkeyed-2 = "<cmd>Lspsaga peek_definition<CR>";
          desc = "LspSaga Definition";
        }
        {
          __unkeyed-1 = "<Leader>la";
          __unkeyed-2 = "<cmd>Lspsaga code_action<CR>";
          desc = "LspSaga Action";
        }
      ];
    };
    settings = {
      finder = {
        number = true;
        relativenumber = false;
      };
      symbol_in_winbar = {
        enable = false;
      };
      implement = {
        enable = false;
      };
      lightbulb = {
        enable = false;
        virtual_text = false;
      };
      ui = {
        title = false;
        code_action = "";
        expand = "";
        collapse = "";
        lines = [
          "└"
          "├"
          "│"
          ""
          "┌"
        ];
      };
    };
  };
}
