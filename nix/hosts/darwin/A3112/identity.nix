rec {
  system = "aarch64-darwin";
  hostname = "A3112";
  username = "shouta";
  homeDirectory = "/Users/${username}";
  flakeRoot = "${homeDirectory}/.local/share/chezmoi/nix";
  git = {
    user.name = "5h0utat0t2uka";
    user.email = "37361670+5h0utat0t2uka@users.noreply.github.com";
  };
}
