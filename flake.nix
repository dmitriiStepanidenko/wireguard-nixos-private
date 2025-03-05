{
  description = "WireGuard with sops-nix integration NixOS module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # NixOS modules
    nixosModules = {
      wireguard = import ./wireguard.nix;
      default = self.nixosModules.wireguard;
    };

    # For backwards compatibility
    nixosModule = self.nixosModules.default;
  };
}
