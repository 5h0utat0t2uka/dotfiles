{ pkgs, ... }:

let
  passage-otp = pkgs.writeShellApplication {
    name = "passage-otp";
    runtimeInputs = [
      pkgs.passage
      pkgs.python3
    ];

    text = ''
      if [ "$#" -ne 1 ]; then
        echo "Usage: passage-otp <passage-entry>" >&2
        exit 2
      fi

      exec python3 - "$1" <<'PY'
      import base64
      import hashlib
      import hmac
      import subprocess
      import sys
      import time
      from urllib.parse import parse_qs, urlparse

      name = sys.argv[1]

      result = subprocess.run(
          ["passage", "show", name],
          check=True,
          stdout=subprocess.PIPE,
          text=True,
      )

      uri = next(
          (
              line.strip()
              for line in result.stdout.splitlines()
              if line.startswith("otpauth://totp/")
          ),
          None,
      )

      if uri is None:
          print(f"passage-otp: no TOTP URI found in {name}", file=sys.stderr)
          sys.exit(1)

      query = parse_qs(urlparse(uri).query)

      try:
          secret = query["secret"][0].replace(" ", "").upper()
          digits = int(query.get("digits", ["6"])[0])
          period = int(query.get("period", ["30"])[0])
          algorithm = query.get("algorithm", ["SHA1"])[0].upper()
      except (KeyError, ValueError):
          print("passage-otp: invalid TOTP URI", file=sys.stderr)
          sys.exit(1)

      hashes = {
          "SHA1": hashlib.sha1,
          "SHA256": hashlib.sha256,
          "SHA512": hashlib.sha512,
      }

      if algorithm not in hashes:
          print(
              f"passage-otp: unsupported algorithm: {algorithm}",
              file=sys.stderr,
          )
          sys.exit(1)

      try:
          key = base64.b32decode(secret + "=" * (-len(secret) % 8))
      except Exception:
          print("passage-otp: invalid Base32 secret", file=sys.stderr)
          sys.exit(1)

      counter = int(time.time()) // period
      digest = hmac.new(
          key,
          counter.to_bytes(8, "big"),
          hashes[algorithm],
      ).digest()

      offset = digest[-1] & 0x0F
      code = (
          int.from_bytes(digest[offset:offset + 4], "big") & 0x7FFFFFFF
      ) % (10 ** digits)

      print(f"{code:0{digits}d}")
      PY
    '';
  };
in
{
  home.packages = [
    pkgs.passage
    passage-otp
  ];
}
