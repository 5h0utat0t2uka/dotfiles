{ pkgs, ... }:

let
  passWithOtp = pkgs.pass.withExtensions (exts: [
    exts.pass-otp
  ]);
  pass-editor = pkgs.writeShellScriptBin "pass" ''
    exec env EDITOR=vim VISUAL=vim ${passWithOtp}/bin/pass "$@"
  '';
in
{
  home.packages = [
    pass-editor
  ];
}
