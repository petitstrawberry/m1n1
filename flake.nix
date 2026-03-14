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

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      rust-overlay,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };

        pythonEnv = pkgs.python3.withPackages (
          ps: with ps; [
            pyserial
            construct
          ]
        );

        debuggerPkg =
          if pkgs.stdenv.hostPlatform.isDarwin then
            pkgs.writeShellScriptBin "gdb" ''
              exec ${pkgs.lldb}/bin/lldb "$@"
            ''
          else
            pkgs.gdb;

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

          src = builtins.path {
            path = ./.;
            name = "m1n1-src";
          };

          nativeBuildInputs = with pkgs; [
            llvmPackages_18.clang
            llvmPackages_18.bintools
            llvmPackages_18.llvm
            pythonEnv
            (rust-bin.stable.latest.default.override {
              targets = [ "aarch64-unknown-none-softfloat" ];
            })
            gnumake
            git
          ];

          makeFlags = [
            "RELEASE=1"
            "USE_CLANG=1"
            "TOOLCHAIN=${pkgs.clang}/bin/"
            "LLDDIR=${pkgs.lld}/bin/"
            "LLVM_CONFIG=${pkgs.llvmPackages_18.llvm}/bin/llvm-config"
            "CC=${pkgs.llvmPackages_18.clang}/bin/clang"
            "LD=${pkgs.llvmPackages_18.bintools}/bin/ld.lld"
            "OBJCOPY=${pkgs.llvmPackages_18.llvm}/bin/llvm-objcopy"
          ];

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp build/m1n1.bin $out/
            cp build/m1n1.macho $out/
            runHook postInstall
          '';
        };

      in
      {
        packages = {
          default = m1n1;
          inherit m1n1;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            pythonEnv
            gnumake
            git
            tmux
            lldb
            llvmPackages_18.clang-unwrapped
            llvmPackages_18.lld
            llvmPackages_18.llvm
            (rust-bin.stable.latest.default.override {
              targets = [ "aarch64-unknown-none-softfloat" ];
            })
          ];

          LLVM_CONFIG = "${pkgs.llvmPackages_18.llvm}/bin/llvm-config";

          shellHook = ''
            export LLVM_CONFIG
            export TOOLCHAIN="${pkgs.llvmPackages_18.clang-unwrapped}/bin/"
            export LLDDIR="${pkgs.llvmPackages_18.lld}/bin/"
            export PATH="${pkgs.llvmPackages_18.clang-unwrapped}/bin:${pkgs.llvmPackages_18.lld}/bin:${pkgs.llvmPackages_18.llvm}/bin:$PATH"
            echo "m1n1 development environment"
            echo ""
            echo "Build:"
            echo "  make RELEASE=1"
            echo ""
            echo "Proxy shell:"
            echo "  python proxyclient/tools/shell.py"
            echo ""
            echo "U-Boot under HV (u-boot.bin required):"
            echo "  python proxyclient/tools/run_guest.py -r payloads/u-boot-nodtb.bin -E 2048"
            echo ""
            echo "Chainload boot.bin:"
            echo "  python proxyclient/tools/chainload.py -r payloads/boot-j293.bin"
          '';
        };
      }
    );
}
