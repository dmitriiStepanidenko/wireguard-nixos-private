{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.wireguard;
in {
  options.services.wireguard = {
    enable = mkEnableOption "WireGuard with sops-nix integration";

    interface = mkOption {
      type = types.str;
      default = "wg0";
      description = "Wireguard interface name";
    };

    ips = mkOption {
      type = types.str;
      description = "IP address of interface";
    };

    listenPort = mkOption {
      type = types.port;
      default = 51820;
      description = "WireGuard listen port";
    };

    privateKeyFile = mkOption {
      type = types.str;
      description = "Private key file path";
    };

    peers = mkOption {
      type = types.listOf (types.submodule {
        options = {
          publicKeyFile = mkOption {
            type = types.str;
            description = "Peer public key file";
          };
          presharedKeyFile = mkOption {
            type = types.str;
            description = "Peer preshared key file";
          };
          allowedIPs = mkOption {
            type = types.str;
            description = "Allowed IP ranges for this peer";
          };
          endpointFile = mkOption {
            type = types.nullOr types.str;
            description = "Peer endpoint address file";
          };
          endpointPort = mkOption {
            type = types.port;
            default = 51820;
            description = "WireGuard endpoint port";
          };
        };
      });
      default = [];
      description = "WireGuard peers configuration";
    };
  };

  config = mkIf cfg.enable (let
    wgScript = let
      peerConfigs =
        map (
          peer:
            "${pkgs.wireguard-tools}/bin/wg set ${cfg.interface} "
            + "private-key ${cfg.privateKeyFile} "
            + "peer $(cat ${peer.publicKeyFile}) "
            + "preshared-key ${peer.presharedKeyFile} "
            + "allowed-ips ${peer.allowedIPs} "
            + "persistent-keepalive 7 "
            + "endpoint $(cat ${peer.endpointFile}):${toString peer.endpointPort}"
        )
        cfg.peers;
    in ''
      ${concatStringsSep "\n" peerConfigs}
    '';
  in {
    boot.kernelModules = ["wireguard"];

    environment.systemPackages = with pkgs; [
      wireguard-tools
    ];

    networking.firewall.allowedUDPPorts = [cfg.listenPort];

    systemd.services."wireguard-setup" = {
      description = "Setup WireGuard with secrets";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "nss-lookup.target"];
      wants = ["network-online.target" "nss-lookup.target"];
      path = with pkgs; [kmod iproute2 wireguard-tools];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        NetworkNamespacePath = "";
      };

      script = ''
        if ip link show ${cfg.interface} &> /dev/null; then
          echo "${cfg.interface} interface exists. Deleting it... "
          ip link delete ${cfg.interface}
          echo "${cfg.interface} interface deleted."
        else
          echo "${cfg.interface} interface does not exist."
        fi

        ip link add dev ${cfg.interface} type wireguard
        ip address add dev ${cfg.interface} ${cfg.ips}

        ${wgScript}

        ip link set up dev ${cfg.interface}
      '';
    };

    systemd.network.wait-online.ignoredInterfaces = [cfg.interface];
  });
}

