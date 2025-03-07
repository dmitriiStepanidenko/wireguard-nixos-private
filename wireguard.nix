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
    watchdog = {
      enable = mkEnableOption "Enable WireGuard watchdog service";

      pingIP = mkOption {
        type = types.str;
        description = "IP address to ping for connectivity check";
        example = "10.0.0.1";
      };

      interval = mkOption {
        type = types.int;
        default = 30;
        description = "Interval in seconds between connectivity checks";
      };

      pingCount = mkOption {
        type = types.int;
        default = 3;
        description = "Number of pings to send for each check";
      };

      pingTimeout = mkOption {
        type = types.int;
        default = 5;
        description = "Timeout in seconds for ping";
      };
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
    systemd.services = {
      "wireguard-setup" = {
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
      "wireguard-watchdog" = mkIf cfg.watchdog.enable {
        description = "WireGuard connection watchdog";
        after = ["wireguard-setup.service"];
        wants = ["wireguard-setup.service"];
        path = with pkgs; [iproute2 iputils];

        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "${cfg.watchdog.interval}s";
          User = "root";
        };

        script = ''
          while true; do
            # Check if the interface is up
            if ! ip link show ${cfg.interface} &> /dev/null; then
              echo "WireGuard interface ${cfg.interface} not found. Restarting service..."
              systemctl restart wireguard-setup.service
              sleep ${toString cfg.watchdog.interval}
              continue
            fi

            # Try to ping through the WireGuard interface
            if ! ${pkgs.unixtools.ping}/bin/ping -I ${cfg.interface} -c ${toString cfg.watchdog.pingCount} -W ${toString cfg.watchdog.pingTimeout} ${cfg.watchdog.pingIP} &> /dev/null; then
              echo "Ping to ${cfg.watchdog.pingIP} failed. Restarting WireGuard service..."
              systemctl restart wireguard-setup.service
            else
              echo "Ping to ${cfg.watchdog.pingIP} successful. WireGuard connection is working."
            fi

            # sleep ${toString cfg.watchdog.interval}
          done
        '';
      };
    };

    systemd.network.wait-online.ignoredInterfaces = [cfg.interface];
  });
}
