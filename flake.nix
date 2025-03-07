{
  description = "WireGuard with sops-nix integration NixOS module + simple watchdog";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
      }
    )
    // {
      nixosModules.default = import ./wireguard.nix;
      # For backwards compatibility
      nixosModule = self.nixosModules.default;
    };
}
