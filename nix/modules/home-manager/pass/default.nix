{ pkgs, ... }:

let
  # passWithOtp = pkgs.pass.withExtensions (exts: [
  #   exts.pass-otp
  # ]);
  passWithOtp = pkgs.pass.withExtensions (exts: [
    (exts.pass-otp.overrideAttrs (
      old:
      pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        # Restore the previous URI parser on macOS.
        patchPhase = (old.patchPhase or "") + ''
          substituteInPlace otp.bash \
            --replace-fail \
              '^otpauth:\/\/(totp|hotp)(\/(([^:?]+)?(:([^:?]*))?)(:([0-9]+))?)?\?(.+)$' \
              '^otpauth:\/\/(totp|hotp)(\/(([^:?]+)?(:([^:?]*))?))?\?(.+)$' \
            --replace-fail \
              'local p=''${BASH_REMATCH[9]}' \
              'local p=''${BASH_REMATCH[7]}'
        '';
      }
    ))
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
