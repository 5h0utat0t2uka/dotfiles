{ ... }:

final: prev: {
  termscp = prev.termscp.overrideAttrs (old: {
    doCheck = false;
    doInstallCheck = false;
    checkPhase = "true";
    installCheckPhase = "true";

    nativeInstallCheckInputs = [ ];
  });
}
