{ pkgs, ... }:

let
  key-menu-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "key-menu.nvim";
    version = "unstable-171ad5c";
    src = pkgs.fetchFromGitHub {
      owner = "emmanueltouzery";
      repo = "key-menu.nvim";
      rev = "171ad5c40fe978ebba86026beac1ac3ed8eda42d";
      hash = "sha256-Nh6pXd0UxLlD6BsOge8I2Rh8Gyt8VmxL7tVIca0ozj8=";
    };

    # src = builtins.fetchGit {
    #   url = "https://github.com/emmanueltouzery/key-menu.nvim.git";
    #   rev = "171ad5c40fe978ebba86026beac1ac3ed8eda42d";
    # };
  };
in
{
  extraPlugins = [
    {
      plugin = key-menu-nvim;
      optional = true;
    }
  ];
  extraConfigLua = ''
    vim.o.timeoutlen = 300
  '';
  plugins.lz-n.plugins = [
    {
      __unkeyed-1 = "key-menu.nvim";
      event = "DeferredUIEnter";
      after = ''
        function()
          require("key-menu").set("n", "<Space>")
          require("key-menu").set("n", "g")
        end
      '';
    }
  ];
}
