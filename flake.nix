{
  description = "m1n1 - Apple Silicon bootloader and hypervisor";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };

        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          pyserial
          construct
        ]);

        buildInputs = with pkgs; [
          pythonEnv
          llvmPackages_18.clang
          llvmPackages_18.bintools
          llvmPackages_18.llvm
          (rust-bin.stable.latest.default.override {
            targets = [ "aarch64-unknown-none-softfloat" ];
          })
          gnumake
          git
        ];

        m1n1 = pkgs.stdenvNoCC.mkDerivation {
          pname = "m1n1";
          version = "unstable-${self.shortRev or "dirty"}";

          src = ./.;

          nativeBuildInputs = buildInputs;

          makeFlags = [
            "RELEASE=1"
            "USE_CLANG=1"
          ];

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp build/m1n1.bin $out/
            cp build/m1n1.macho $out/
            runHook postInstall
          '';
        };

      in {
        packages = {
          default = m1n1;
          inherit m1n1;
        };

        devShells.default = pkgs.mkShell {
          inherit buildInputs;

          shellHook = ''
            export LLVM_CONFIG=${pkgs.llvmPackages_18.llvm.dev}/bin/llvm-config
            echo "m1n1 development environment"
            echo "Build: make RELEASE=1"
            echo "Proxy: python proxyclient/tools/shell.py"
          '';
        };
      }
    );
}
