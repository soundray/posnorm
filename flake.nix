{
  description = "Positional normalization for brain MRI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      posnorm = import ./default.nix { inherit pkgs; };
    in {
      packages.${system} = {
        inherit posnorm;
        default = posnorm;
      };
    };
}
