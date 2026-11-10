{ ... }:

{
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        tabWidth = 2;
        theme = {
          activeBorderColor = [
            "#81A1C1"
            "bold"
          ];
          inactiveBorderColor = [ "#4C566A" ];
          searchingActiveBorderColor = [
            "#B48EAD"
            "bold"
          ];
        };
      };
    };
  };
}
