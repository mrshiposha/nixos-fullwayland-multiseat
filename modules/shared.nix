{ config, lib, pkgs, ... }:
with lib;
with types;
let
  cfg = config.shared;
  sharedDirOptions = {
    source = mkOption {
      type = path;
    };

    createSource = mkOption {
      type = bool;
      default = false;
    };

    mount = {
      point = mkOption {
        type = path;
      };
      ownerId = mkOption {
        type = int;
      };
      groupId = mkOption {
        type = int;
      };
    }; 
  };
in
{
  options.shared = {
    directories = mkOption {
      type = listOf (submodule {
        options = sharedDirOptions;
      });
      default = [];
    };
  };

  config =
  let
    directoriesNum = (builtins.length cfg.directories);
  in mkIf (directoriesNum > 0) {
    systemd.tmpfiles.rules = lists.unique (
      builtins.map
        (dir: "d ${builtins.toString dir.source} 0755 root root - -")
        (builtins.filter (dir: dir.createSource) cfg.directories)
    );

    fileSystems = builtins.listToAttrs (
      builtins.map
        (dir: attrsets.nameValuePair (builtins.toString dir.mount.point) {
          device = builtins.toString dir.source;
          fsType = "none";
          options =
          let
            rootUid = "0";
            rootGid = "0";
            ownerId = builtins.toString dir.mount.ownerId;
            groupId = builtins.toString dir.mount.groupId;
            idmap = ''"u:${rootUid}:${ownerId}:1 g:${rootGid}:${groupId}:1"'';
          in [
            "defaults"
            "bind"
            "X-mount.mkdir"
            "X-mount.idmap=${idmap}"
          ];
        })
        cfg.directories
    );
  };
}
