{
  description = "WFVM: Windows Functional Virtual Machine";

  inputs = {
  };

  outputs = { self, nixpkgs }:
    let
      # only x64 is supported
      system = "x86_64-linux";

      pkgs = nixpkgs.legacyPackages.${system};

    in {
      lib = import ./wfvm {
        inherit pkgs;
      };
    };
}
