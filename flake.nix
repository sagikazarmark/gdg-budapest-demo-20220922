{
  description = "GDG Budapest demo: Deep dive into Kubernetes secrets";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            google-cloud-sdk
            kubectl
            kubernetes-helm
            kustomize
          ];
        };
      });
}
