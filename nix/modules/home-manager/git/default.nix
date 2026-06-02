{ pkgs, identity, ... }:

{
  programs.git = {
    enable = true;
    ignores = [
      ".DS_Store"
      "**/.claude/settings.local.json"
    ];
    settings = {
      user = {
        name = identity.git.user.name;
        email = identity.git.user.email;
      };
      core = {
        editor = "vim";
        pager = "delta";
      };
      url."git@github.com:" = {
        insteadOf = "https://github.com/";
      };
      alias = {
        sync = "!git fetch origin && git switch dev && git pull --ff-only origin dev && git merge origin/main && git push origin dev";
      };
      interactive = { diffFilter = "delta --color-only"; };
      merge = { conflictstyle = "diff3"; };
      diff = { colorMoved = "default"; };
      init = { defaultBranch = "main"; };
      push = { autoSetupRemote = true; };
      delta = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        syntax-theme = "Nord";
        file-style = "bold green";
        file-decoration-style = "none";
        line-numbers-left-format = "{nm:>4} ";
        line-numbers-right-format = "{np:>4} ";
        hunk-header-decoration-style = "none";
      };
      ghq = {
        user = identity.git.user.name;
        root = "${identity.homeDirectory}/Development/repositories";
      };
    };
  };
  home.packages = with pkgs; [
    delta
    ghq
  ];
}
