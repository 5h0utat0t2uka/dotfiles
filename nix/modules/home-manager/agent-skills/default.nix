{ inputs, lib, ... }:

{
  imports = [
    inputs.agent-skills.homeManagerModules.default
  ];

  programs.agent-skills = {
    enable = true;
    sources = {
      cloudflare = {
        input = "cloudflare-skills";
        subdir = "skills";
      };
      ax = {
        input = "ax";
        subdir = "skills";
      };
    };

    # Keep the existing selection; upstream additions are not installed automatically.
    skills.enable = [
      "agents-sdk"
      "ax"
      "cloudflare"
      "cloudflare-email-service"
      "cloudflare-one"
      "cloudflare-one-migrations"
      "durable-objects"
      "sandbox-migrate-to-next"
      "sandbox-next"
      "sandbox-stable"
      "turnstile-spin"
      "web-perf"
      "workers-best-practices"
      "wrangler"
    ];

    targets = {
      # Codex and Zed share this directory; do not install a second copy in .codex.
      agents = {
        enable = true;
        dest = ".agents/skills";
        structure = "link";
      };
      claude = {
        enable = true;
        dest = ".claude/skills";
        structure = "link";
      };
      copilot = {
        enable = true;
        dest = ".copilot/skills";
        structure = "link";
      };
    };
  };

  # Upstream enables force for link targets. Require explicit cleanup before
  # the first activation instead of overwriting the existing CLI-managed files.
  home.file = {
    ".agents/skills".force = lib.mkForce false;
    ".claude/skills".force = lib.mkForce false;
    ".copilot/skills".force = lib.mkForce false;
  };
}
