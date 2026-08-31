{ ... }:

{
  programs.gpg = {
    enable = true;
    scdaemonSettings = {
      application-priority = "piv";
    };
  };

  home.file.".gnupg/common.conf".text = ''
    use-keyboxd
  '';
}
