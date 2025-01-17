{ config, lib, ... }:
with builtins;
with lib;
with lib.types;
with lib.attrsets;

let
  cfg = config.security.poly;
in
{
  options.security.poly = {
    enable = mkOption {
      type = bool;
      default = false;
    };

    services = mkOption {
      type = listOf str;
    };

    instances = mkOption {
      type = listOf (submodule {
        options = rec {
          mount = mkOption {
            type = str;
          };

          owner = mkOption {
            type = nullOr str;
            default = null;
          };

          mode = mkOption {
            type = str;
            default = "0755";
          };

          group = mkOption {
            type = nullOr str;
            default = null;
          };

          source = mkOption {
            type = path;
            default = /poly + mount;
          };

          type = mkOption {
            type = enum [
              "tmpfs"
              "tmpdir"
              "user"
            ];
          };

          ignoreFor = mkOption {
            type = listOf str;
            default = [ "root" ];
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = lists.unique (
      map
        (instance:
          let sourceParent = toString (dirOf instance.source);
          in if sourceParent == "/"
          then ""
          else "d ${sourceParent} 000 root root -")
        cfg.instances
    );

    security.pam.services = listToAttrs
      (map
        (service: {
          name = service;
          value = {
            text = mkDefault (
              mkAfter "session required pam_namespace.so\n"
            );
          };
        })
        cfg.services
      );

    environment.etc = {
      "security/namespace.conf".text =
        strings.concatLines (
          builtins.map
            (options:
              let
                ignoreFor = concatStringsSep "," options.ignoreFor;
                owner = if options.owner == null
                  then ""
                  else options.owner;
                group = if options.group == null
                  then ""
                  else options.group;
                createOptions = "create=${options.mode},${owner},${group}";
              in
              "${options.mount}    ${toString options.source}    ${options.type}:${createOptions}    ${ignoreFor}")
            cfg.instances
        );
    };
  };
}
