{ config, ... }:

{
  programs.starship = {
    enable = true;
    configPath = "${config.xdg.configHome}/starship/starship.toml";
    settings = {
      scan_timeout = 25;
      command_timeout = 500;
      add_newline = true;

      format = ''
        [┌─](bold black) $hostname $directory $git_branch$git_status$fill$cmd_duration''${custom.chezmoi}$nodejs$nix_shell$time
        [└─](bold black) $character
      '';

      character = {
        success_symbol = "[❯](green)";
        error_symbol = "[❯](red)";
      };
      fill = {
        symbol = " ";
      };
      hostname = {
        ssh_only = false;
        format = "[$hostname](green)";
      };
      directory = {
        format = "[$path]($style)";
        style = "blue";
        read_only = "";
        truncation_length = 1;
        truncation_symbol = "";
        fish_style_pwd_dir_length = 1;
        truncate_to_repo = false;
      };
      git_branch = {
        symbol = "";
        format = "[on](white) [$branch](green)";
      };
      git_status = {
        format = "$all_status$ahead_behind";
        conflicted = "[ =\${count}](bold red)";
        ahead = "[ ↑\${count}](blue)";
        behind = "[ ↓\${count}](red)";
        diverged = "[ \${ahead_count}\${behind_count}](purple)";
        untracked = "[ ?\${count}](green)";
        stashed = "[ *\${count}](purple)";
        modified = "[ !\${count}](yellow)";
        staged = "[ +\${count}](blue)";
        renamed = "[ ~\${count}](yellow)";
        deleted = "[ -\${count}](red)";
      };
      cmd_duration = {
        min_time = 3000;
        format = "[$duration](yellow)  ";
      };
      custom.chezmoi = {
        command = "printf ''";
        when = ''
          test "''${CHEZMOI:-}" = "1"
        '';
        format = "[$output](blue)  ";
        shell = [ "sh" ];
      };
      python = {
        symbol = " ";
        version_format = "$raw";
        format = "[$symbol$version](green)  ";
        python_binary = "['python', 'python3']";
      };
      bun = {
        symbol = " ";
        version_format = "$raw";
        format = "[$symbol$version](green)  ";
      };
      nodejs = {
        symbol = " ";
        version_format = "$raw";
        format = "[$symbol$version](green)  ";
      };
      nix_shell = {
        symbol = " ";
        format = "[$symbol$state](blue) ";
        # format = "[$symbol$state(\\($name\\))](blue) ";
        # impure_msg = "impure";
        impure_msg = "\\(nix dev-shell\\)";
        pure_msg = "pure";
      };
      time = {
        disabled = false;
        format = "[$time](bright-black)";
        time_format = "%H:%M:%S";
      };
    };
  };
}
