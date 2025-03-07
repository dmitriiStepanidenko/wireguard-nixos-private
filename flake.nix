{
  description = "WireGuard with sops-nix integration NixOS module + simple watchdog";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {self, ...}: {
    # NixOS modules
    nixosModules = {
      wireguard = import ./wireguard.nix;
      default = self.nixosModules.wireguard;
    };

    # For backwards compatibility
    nixosModule = self.nixosModules.default;
  };
}
