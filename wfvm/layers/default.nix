{ pkgs }:
let wfvm = import ../. { inherit pkgs; };
in {
  anaconda3 = {
    name = "Anaconda3";
    script = let
      Anaconda3 = pkgs.fetchurl {
        name = "Anaconda3.exe";
        url =
          "https://repo.anaconda.com/archive/Anaconda3-2021.05-Windows-x86_64.exe";
        sha256 = "1lpk7k4gydyk524z1nk4rrninrwi20g2ias2njc9w0a40hwl5nwk";
      };
    in ''
      ln -s ${Anaconda3} ./Anaconda3.exe
      win-put Anaconda3.exe .
      echo Running Anaconda installer...
      win-exec 'start /wait "" .\Anaconda3.exe /S /D=%UserProfile%\Anaconda3'
      echo Anaconda installer finished
    '';
  };
  valhalla_supermassive = {
    name = "Valhalla Supermassive";
    script = let
      Valhalla = pkgs.fetchzip {
        url =
          "https://valhallaproduction.s3.us-west-2.amazonaws.com/supermassive/ValhallaSupermassiveWin_V3_0_0b3.zip";
        sha256 = "sha256-BU7Neha2idSov2m1m8bgnBEV+iqW+Hovs9rsVTBjesk=";
      };
    in ''
      ln -s ${Valhalla}/ValhallaSupermassiveWin_V3_0_0b3.exe ./ValhallaSupermassiveWin_V3_0_0b3.exe
      win-put ValhallaSupermassiveWin_V3_0_0b3.exe .
      echo "Installing Valhalla Supermassive..."
      win-exec 'start /wait "" .\ValhallaSupermassiveWin_V3_0_0b3.exe /SP- /Silent /suppressmsgboxes'
      echo "Valhalla Supermassive installed"
    '';
  };
  audiogridder = {
    name = "Audiogridder";
    script = let
      Audiogridder = pkgs.fetchurl {
        name = "AudioGridderServer_1.2.0.exe";
        url = "https://audiogridder.com/releases/AudioGridderServer_1.2.0.exe";
        sha256 = "sha256-WNDWQpb0tmfi5++Bu9eWTxDiuGUlXxOAcENKsvoBXuA=";
      };
    in ''
      ln -s ${Audiogridder} ./AudioGridderServer_1.2.0.exe
      win-put AudioGridderServer_1.2.0.exe .
      echo "Installing Audiogridder..."
      win-exec 'start /wait "" .\AudioGridderServer_1.2.0.exe /SP- /Silent /suppressmsgboxes'
      echo "Creating startup symlink..."
      win-exec 'mklink "C:\Users\audiogridder\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\AudioGridderServer.exe" "C:\Program Files\AudioGridderServer\AudioGridderServer.exe"'
      echo "Audiogridder installed"
    '';
  };
  msys2 = {
    name = "MSYS2";
    buildInputs = [ pkgs.expect ];
    script = let
      msys2 = pkgs.fetchurl {
        name = "msys2.exe";
        url =
          "https://github.com/msys2/msys2-installer/releases/download/2020-06-02/msys2-x86_64-20200602.exe";
        sha256 = "1mswlfybvk42vdr4r85dypgkwhrp5ff47gcbxgjqwq86ym44xzd4";
      };
      msys2-auto-install = pkgs.fetchurl {
        url =
          "https://raw.githubusercontent.com/msys2/msys2-installer/7b4b35f65904d03399d5dfb8fc4e5729b0b4d81f/auto-install.js";
        sha256 = "17fq1xprbs00j8wb4m0w1x4dvb48qb5hwa3zx77snlhw8226d81y";
      };
    in ''
      ln -s ${msys2} ./msys2.exe
      ln -s ${msys2-auto-install} ./auto-install.js
      win-put msys2.exe .
      win-put auto-install.js .
      echo Running MSYS2 installer...
      # work around MSYS2 installer bug that prevents it from closing at the end of unattended install
      expect -c 'set timeout 600; spawn win-exec ".\\msys2.exe --script auto-install.js -v InstallPrefix=C:\\msys64"; expect FinishedPageCallback { close }'
      echo MSYS2 installer finished
    '';
  };
  msys2-packages = msys-packages: {
    name = "MSYS2-packages";
    script = let
      msys-packages-put = pkgs.lib.strings.concatStringsSep "\n"
        (map (package: "win-put ${package} 'msyspackages' ") msys-packages);
      # Windows command line is so shitty it can't even do glob expansion. Why do people use Windows?
    in ''
      win-exec 'mkdir msyspackages'
      ${msys-packages-put}
      cat > installmsyspackages.bat << EOF
      set MSYS=c:\msys64
      set ARCH=64
      set PATH=%MSYS%\usr\bin;%MSYS%\mingw%ARCH%\bin;%PATH%
      bash -c "pacman -U --noconfirm C:/Users/wfvm/msyspackages/*"
      EOF
      win-put installmsyspackages.bat .
      win-exec installmsyspackages
    '';
  };
  msvc = {
    # Those instructions are vaguely correct:
    # https://docs.microsoft.com/en-us/visualstudio/install/create-an-offline-installation-of-visual-studio?view=vs-2019
    name = "MSVC";
    script = let
      bootstrapper = pkgs.fetchurl {
        name = "RESTRICTDIST-vs_Community.exe";
        url = "https://aka.ms/vs/16/release/vs_community.exe";
        sha256 = "sha256-l4ZKFZTgHf3BmD0eFWyGwsvb4lqB/LiQYizAABOs3gg=";
      };
      # This touchy-feely "community" piece of trash seems deliberately crafted to break Wine, so we use the VM to run it.
      download-vs = wfvm.utils.wfvm-run {
        name = "download-vs";
        image = wfvm.makeWindowsImage { };
        isolateNetwork = false;
        script = ''
          ln -s ${bootstrapper} vs_Community.exe
          ${wfvm.utils.win-put}/bin/win-put vs_Community.exe
          rm vs_Community.exe
          ${wfvm.utils.win-exec}/bin/win-exec "vs_Community.exe --quiet --norestart --layout c:\vslayout --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --lang en-US"
          ${wfvm.utils.win-get}/bin/win-get /c:/vslayout
        '';
      };
      cache = pkgs.stdenv.mkDerivation {
        name = "RESTRICTDIST-vs";

        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = "sha256-GoOKzln8DXVMx52jWGEjwkOFkpSW+wEffAVmBVugIyk=";

        phases = [ "buildPhase" ];
        buildInputs = [ download-vs ];
        buildPhase = ''
          mkdir $out
          cd $out
          wfvm-run-download-vs
        '';
      };
    in ''
      ln -s ${cache}/vslayout vslayout
      win-put vslayout /c:/
      echo "Running Visual Studio installer"
      win-exec "cd \vslayout && start /wait vs_Community.exe --passive --wait && echo %errorlevel%"
    '';
  };
  # You need to run the IDE at least once or else most of the Visual Studio trashware won't actually work.
  # With the /ResetSettings flag, it will actually start without pestering you about opening a Microsoft account.
  msvc-ide-unbreak = {
    name = "MSVC-ide-unbreak";
    script = ''
      win-exec 'cd "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\Common7\IDE" && devenv /ResetSettings'
      sleep 40
    '';
  };
  # Disable the Windows firewall
  disable-firewall = {
    name = "disable-firewall";
    script = ''
      echo Disabling firewall
      win-exec "netsh advfirewall set allprofiles state off"
    '';
  };
  # Disable automatic power management which causes the machine to go
  # into standby after periods without mouse wiggling.
  disable-autosleep = {
    name = "disable-autosleep";
    script = ''
      echo Disabling autosleep
      win-exec "powercfg /x -hibernate-timeout-ac 0"
      win-exec "powercfg /x -hibernate-timeout-dc 0"
      win-exec "powercfg /x -disk-timeout-ac 0"
      win-exec "powercfg /x -disk-timeout-dc 0"
      win-exec "powercfg /x -monitor-timeout-ac 0"
      win-exec "powercfg /x -monitor-timeout-dc 0"
      win-exec "powercfg /x -standby-timeout-ac 0"
      win-exec "powercfg /x -standby-timeout-dc 0"
    '';
  };
  # Turn off automatic locking of idle user sessions
  disable-autolock = {
    name = "disable-autolock";
    script = ''
      echo Disabling autolock
      win-exec "reg add HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\Personalization /v NoLockScreen /t REG_DWORD /d 1"
    '';
  };
  # Don't let Windows start completely rewriting gigabytes of disk
  # space. Defragmentation increases the size of our qcow layers
  # needlessly.
  disable-scheduled-defrag = {
    name = "disable-scheduled-defrag";
    script = ''
      echo Disabling scheduled defragmentation service
      win-exec 'schtasks /Change /DISABLE /TN "\Microsoft\Windows\Defrag\ScheduledDefrag"'
    '';
  };

  # Chain together layers that are quick to run so that the VM does
  # not have to be started/shutdown for each.
  collapseLayers = scripts: {
    name = pkgs.lib.concatMapStringsSep "-" ({ name, ... }: name) scripts;
    script =
      builtins.concatStringsSep "\n" (map ({ script, ... }: script) scripts);
    buildInputs =
      builtins.concatMap ({ buildInputs ? [ ], ... }: buildInputs) scripts;
  };
}
