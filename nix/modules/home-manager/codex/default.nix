{ ... }:

{
  programs.codex = {
    enable = true;
    mutableSettings = true;

    settings = {
      default_permissions = "workspace-only";
      approval_policy = "on-request";
      approvals_reviewer = "user";

      permissions.workspace-only = {
        extends = ":workspace";

        filesystem = {
          ":root" = "deny";
          ":minimal" = "read";
          ":tmpdir" = "deny";
          ":slash_tmp" = "deny";
          "~/.agents/skills" = "read";
          "~/.codex/skills" = "read";
          "~/.codex/plugins/cache" = "read";
          "/nix/store" = "read";
        };
      };
    };
  };
}
