{ config, lib, pkgs, ... }:
with lib;
with types;
let
  cfg = config.multiseat;
  deviceOptions = {
    subsystem = mkOption {
      type = str;
    };
    pci = mkOption {
      type = str;
    };
    kernel = mkOption {
      type = nullOr str;
    };
  };
  seatOptions = {
    devices = mkOption {
      type = listOf (submodule {
        options = deviceOptions;
      });
    };
  };
in
{
  options.multiseat = {
    enable = mkEnableOption "multiseat";

    extraSeats = mkOption {
      type = attrsOf (submodule {
        options = seatOptions;
      });
    };

    driPrimePci = mkOption {
      type = str;
    };
  };

  config = mkIf config.multiseat.enable {
    services.greetd.extraSeats = builtins.attrNames cfg.extraSeats;

    services.udev.packages = builtins.attrValues (
      builtins.mapAttrs
        (seat: options:
        let ruleFile = "15-${seat}.rules"; in pkgs.writeTextFile {
          name = ruleFile;
          text = strings.concatLines (
            builtins.map
              (device: let kernel = strings.optionalString (device.kernel != null) " KERNEL==${device.kernel}"; in
                ''SUBSYSTEM=="${device.subsystem}", KERNELS=="${device.pci}"${kernel}, ENV{ID_SEAT}="${seat}"'')
              options.devices
          );
          destination = "/etc/udev/rules.d/${ruleFile}";
        })
        cfg.extraSeats
    );

    environment.sessionVariables.DRI_PRIME =
      "pci-" + (builtins.replaceStrings [":" "."] ["_" "_"] cfg.driPrimePci);

    # See https://www.freedesktop.org/wiki/Software/systemd/multiseat/
    assertions = lists.flatten (
      attrsets.mapAttrsToList
        (seat: options: [
          {
            assertion = (builtins.stringLength seat) <= 64;
            message = "the seat name is too long (> 64 characters): ${seat}";
          }

          {
            assertion = (builtins.match "seat[A-Za-z0-9_-]+" seat) != null;
            message = ''
              ${seat}: invalid seat name!
              A valid seat name must begin with a word "seat"
              followed by at least one more character from the range a-zA-Z0-9, "_" and "-".
            '';
          }

          {
            assertion =
            let
              drmDevices = builtins.filter
                (dev: dev.subsystem == "drm")
                options.devices;
            in (builtins.length drmDevices) > 0;
            message = "no drm device is found for ${seat}";
          }
        ])
        cfg.extraSeats
    );
  };
}
