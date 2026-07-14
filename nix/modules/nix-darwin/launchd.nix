{ ... }:

let
  # Determinate Nix / unmanaged multi-user Nix のグローバル profile
  nixProfile = "/nix/var/nix/profiles/default";
  nixBin = "${nixProfile}/bin";
in
{
  # ============================================================
  # max open files
  # ============================================================
  launchd.daemons.limit-maxfiles = {
    serviceConfig = {
      ProgramArguments = [
        "/bin/launchctl"
        "limit"
        "maxfiles"
        "65536"
        "524288"
      ];
      RunAtLoad = true;
    };
  };

  # ============================================================
  # Automatic Garbage Collection
  # 毎週日曜日 AM3:00 に gc
  # ============================================================
  launchd.daemons.nix-gc = {
    script = ''
      echo
      echo "=== GC start: $(/bin/date '+%Y-%m-%d %H:%M:%S %z') ==="

      ${nixBin}/nix-collect-garbage --delete-older-than 14d
      status=$?

      echo "=== GC end: $(/bin/date '+%Y-%m-%d %H:%M:%S %z') exit=$status ==="
      exit "$status"
    '';

    serviceConfig = {
      StartCalendarInterval = [
        {
          Weekday = 0;
          Hour = 3;
          Minute = 0;
        }
      ];

      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "/var/log/nix-gc.log";
      StandardErrorPath = "/var/log/nix-gc.log";
    };
  };

  # ============================================================
  # Nix Store Optimization
  # 毎週日曜日 AM4:00 に optimise
  # ============================================================
  launchd.daemons.nix-optimise = {
    script = ''
      echo
      echo "=== optimise start: $(/bin/date '+%Y-%m-%d %H:%M:%S %z') ==="

      ${nixBin}/nix-store --optimise
      status=$?

      echo "=== optimise end: $(/bin/date '+%Y-%m-%d %H:%M:%S %z') exit=$status ==="
      exit "$status"
    '';

    serviceConfig = {
      StartCalendarInterval = [
        {
          Weekday = 0;
          Hour = 4;
          Minute = 0;
        }
      ];

      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "/var/log/nix-optimise.log";
      StandardErrorPath = "/var/log/nix-optimise.log";
    };
  };
}
