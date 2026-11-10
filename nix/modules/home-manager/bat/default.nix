{ ... }:

{
  programs.bat = {
    enable = true;
    config = {
      theme = "Nord";
      style = "numbers,changes,header";
    };
    themes = {
      Nord = {
        src = ./themes;
        file = "Nord.tmTheme";
      };
    };
  };
}
