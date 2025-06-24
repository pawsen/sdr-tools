
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

        # # Python environment with required packages
        mypython = pkgs.python3.withPackages (ps: with ps; [
          numpy
          scipy
          ipython
          matplotlib
        ]);

        # Core SDR packages
        sdrPackages = with pkgs; [
          rtl-sdr
          rtl_433
          urh
          csdr  # cli IQ demodulater
          sox  # convert vaw files
          inspectrum
          # sdrpp
          # audacity
        ];

        # Development tools
        devTools = with pkgs; [
         mypython
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

          buildInputs = sdrPackages ++ devTools ++ (with pkgs; [
            # fix for matplotlib: qt.qpa.plugin: Could not find the Qt platform plugin "xcb"
            pkgs.qt5.qtbase
          ]);

          # Environment variables
          # LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath sdrPackages;
          # PYTHONPATH = "${mypython}/${mypython.sitePackages}";
          shellHook = ''
            echo "SDR Development Environment"
            echo "Python ${mypython.python.version}"
            echo "with numpy ${mypython.pkgs.numpy.version}"
            echo "Available tools: ${builtins.concatStringsSep ", " (map (p: p.pname or p.name) sdrPackages)}"
            # fix for matplotlib: qt.qpa.plugin: Could not find the Qt platform plugin "xcb"
            export QT_QPA_PLATFORM_PLUGIN_PATH="${pkgs.qt5.qtbase}/lib/qt-${pkgs.qt5.qtbase.version}/plugins/platforms"
          '';
        };

        formatter = pkgs.nixpkgs-fmt;
      });
}
