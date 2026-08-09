{ ... }:

{
  programs.mcp.enable = true;

  programs.github-copilot-cli = {
    enable = true;
    enableMcpIntegration = true;
    context = ''
      Respond in Japanese for all explanations, summaries, and code review findings.
    '';
    settings = {
      autoUpdate = false;
      banner = false;
      respectGitignore = true;
      renderMarkdown = true;
      trusted_folders = [
        "/Users/shouta/Development"
      ];
    };
  };
}
