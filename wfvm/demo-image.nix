{ pkgs ? import <nixpkgs> { }
  # Whether to generate just a script to start and debug the windows installation
, impureMode ? false
  # Flake input `self`
, self ? null }:

let
  wfvm = if self == null
  # nix-build
  then
    (import ./default.nix { inherit pkgs; })
    # built from flake.nix
  else
    self.lib;
in wfvm.makeWindowsImage {
  # Build install script & skip building iso
  inherit impureMode;

  # Custom base iso
  windowsImage = pkgs.requireFile rec {
    name = "Win11_23H2_English_x64v2.iso";
    sha256 = "sha256-Nt5ey3oNqljc5owDuUZaVD7Q9UmKqK5gq0X7fIxK5AI=";
    message =
      "Get disk image ${name} from https://www.microsoft.com/en-us/software-download/windows11/";
  };

  # impureShellCommands = [
  #   "powershell.exe echo Hello"
  # ];

  # User accounts
  users = {
    audiogridder = {
      password = "1234";
      # description = "Default user";
      # displayName = "Display name";
      groups = [ "Administrators" ];
    };
  };

  # Auto login
  defaultUser = "audiogridder";

  # fullName = "M-Labs";
  # organization = "m-labs";
  # administratorPassword = "12345";

  # Imperative installation commands, to be installed incrementally
  installCommands = if impureMode then
    [ ]
  else
    with wfvm.layers;
    [
      (collapseLayers [
        disable-autosleep
        disable-autolock
        disable-firewall
        valhalla_supermassive
        audiogridder
      ])
    ];

  # services = {
  #   # Enable remote management
  #   WinRm = {
  #     Status = "Running";
  #     PassThru = true;
  #   };
  # };

  # License key (required)
  # productKey = throw "Search the f* web"
  imageSelection = "Windows 11 Pro N";

  # Locales
  # uiLanguage = "en-US";
  # inputLocale = "en-US";
  # userLocale = "en-US";
  # systemLocale = "en-US";

}
