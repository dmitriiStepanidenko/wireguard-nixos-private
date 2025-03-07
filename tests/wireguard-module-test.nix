# test/wireguard-module-test.nix
import <nixpkgs/nixos/tests/make-test-python.nix> ({
  pkgs,
  lib,
  ...
}: let
  # Mock file paths for keys
  privateKeyPath = "/run/secrets/wireguard-private-key";
  publicKeyPath = "/run/secrets/wireguard-public-key";
  presharedKeyPath = "/run/secrets/wireguard-preshared-key";
  endpointPath = "/run/secrets/wireguard-endpoint";

  # Mock content for the key files
  privateKeyContent = "4I6W8bLYw/q7qyB/q4QqNTLiD9cJLVu1WJv9YC1aqEI=";
  publicKeyContent = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";
  presharedKeyContent = "FpCyhNBXSEVQQzH9rRyOtXBQKUQTf9txnlV1/KsQpRI=";
  endpointContent = "example.com";
in {
  name = "wireguard-module-test";

  nodes = {
    machine = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        ../wireguard.nix
      ];

      # Create mock files for testing
      system.activationScripts.createWireguardSecrets = ''
        mkdir -p /run/secrets
        echo "${privateKeyContent}" > ${privateKeyPath}
        echo "${publicKeyContent}" > ${publicKeyPath}
        echo "${presharedKeyContent}" > ${presharedKeyPath}
        echo "${endpointContent}" > ${endpointPath}
        chmod 600 ${privateKeyPath} ${publicKeyPath} ${presharedKeyPath} ${endpointPath}
      '';

      # Configure the wireguard service
      services.wireguard = {
        enable = true;
        interface = "wg0";
        ips = "10.0.0.1/24";
        listenPort = 51820;
        privateKeyFile = privateKeyPath;

        peers = [
          {
            publicKeyFile = publicKeyPath;
            presharedKeyFile = presharedKeyPath;
            allowedIPs = "10.0.0.2/32";
            endpointFile = endpointPath;
            endpointPort = 51821;
          }
        ];

        watchdog = {
          enable = true;
          pingIP = "10.0.0.2";
          interval = 10;
          pingCount = 2;
          pingTimeout = 3;
        };
      };

      # Ensure the kernel module is available in the VM
      boot.kernelModules = ["wireguard"];

      # Allow the test to access the networking tools
      environment.systemPackages = with pkgs; [
        wireguard-tools
        iproute2
        iputils
      ];
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    ## Test 1: Check if wireguard-setup service is running
    #machine.succeed("systemctl is-active wireguard-setup.service")

    ## Test 2: Check if the wireguard interface exists
    #machine.succeed("ip link show wg0")

    ## Test 3: Check if the interface has the correct IP
    #machine.succeed("ip addr show wg0 | grep -q '10.0.0.1/24'")

    ## Test 4: Check if the wireguard configuration is correct
    #wireguard_config = machine.succeed("wg show wg0")
    #if "listening port: 51820" not in wireguard_config:
    #    raise Exception("Incorrect listening port configuration")

    ## Test 5: Check if peer is configured correctly
    #if "allowed ips: 10.0.0.2/32" not in wireguard_config:
    #    raise Exception("Peer allowed IPs not configured correctly")

    ## Test 6: Check if watchdog service is running
    #machine.succeed("systemctl is-active wireguard-watchdog.service")

    ## Test 7: Simulate interface failure and check recovery
    #machine.succeed("ip link set wg0 down")
    #machine.sleep(15)  # Allow watchdog to detect and fix
    #machine.succeed("ip link show wg0 | grep -q 'UP'")

    ## Test 8: Check firewall configuration
    #firewall_config = machine.succeed("iptables-save")
    #if not any(line.strip() == "-A nixos-fw -p udp -m udp --dport 51820 -j nixos-fw-accept" for line in firewall_config.split("\n")):
    #    raise Exception("Firewall not configured correctly for WireGuard")

    ## Test 9: Test restarting the service
    #machine.succeed("systemctl restart wireguard-setup.service")
    #machine.succeed("systemctl is-active wireguard-setup.service")

    #machine.succeed("echo 'All tests passed!'")
  '';
})
