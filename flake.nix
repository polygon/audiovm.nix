{
  description = "WFVM: Windows Functional Virtual Machine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    current.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs, current }:
    let
      # only x64 is supported
      system = "x86_64-linux";

      pkgs = nixpkgs.legacyPackages.${system};
      qemu = current.legacyPackages.${system}.qemu;

    in rec {
      lib = import ./wfvm { inherit pkgs; };

      packages.${system} = rec {
        demoImage = import ./wfvm/demo-image.nix { inherit self pkgs; };

        default = lib.utils.wfvm-run {
          name = "demo";
          image = demoImage;
          script = let
          in ''
            SSHUSER=audiogridder win-exec '"C:\Program Files\AudioGridderServer\AudioGridderServer.exe"'
            echo "Windows booted. Press Enter to terminate VM."
            read
          '';
          display = true;
          isolateNetwork = true;
          inherit qemu;
        };
      };
    };
}
