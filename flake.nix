
# nix profile install .#packages.x86_64-linux.default
# nix develop . -c $SHELLL
# See which files the packages provide, check the symlinked ./result folder
# nix build .#default
{
  description = "SDR development environment (rtl-sdr, rtl_433, urh, etc.)";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/2795c506fe8fb7b03c36ccb51f75b6df0ab2553f";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Core SDR packages
        sdrPackages = with pkgs; [
          rtl-sdr
          rtl_433
          urh
          csdr  # cli IQ demodulater
          sox  # convert vaw files
          # sdrpp
          # audacity
        ];

        # Python environment with required packages
        python = pkgs.python3.withPackages (ps: with ps; [
          numpy
          scipy
          ipython
          # Add other Python dependencies here
        ]);

        # Development tools
        devTools = with pkgs; [
          python
        ];

      in {
        packages = {
          default = pkgs.symlinkJoin {
            name = "sdr-packages";
            paths = sdrPackages;
          };
        };

        devShells.default = pkgs.mkShell {
          name = "sdr-dev";

          buildInputs = sdrPackages ++ devTools;

          # Environment variables
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath sdrPackages;
          PYTHONPATH = "${python}/${python.sitePackages}";

          shellHook = ''
            echo "SDR Development Environment"
            echo "Python ${python.python.version} with numpy ${pkgs.python3Packages.numpy.version}"
            echo "Available tools: ${builtins.concatStringsSep ", " (map (p: p.pname or p.name) sdrPackages)}"
          '';
        };

        formatter = pkgs.nixpkgs-fmt;
      });
}
