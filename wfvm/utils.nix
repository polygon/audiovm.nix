{ pkgs, baseRtc ? "2022-10-10T10:10:10", cores ? "4", qemuMem ? "4G", efi ? true
, enableTpm ? false, qemu ? pkgs.qemu, ... }:

rec {
  inherit qemu;

  OVMF = pkgs.OVMF.override { secureBoot = true; };

  mkQemuFlags = extraFlags:
    [
      "-enable-kvm"
      "-cpu host"
      "-smp ${cores}"
      "-m ${qemuMem}"
      "-M q35,smm=on"
      "-vga qxl"
      "-rtc base=${baseRtc}"
      "-device qemu-xhci"
      "-device virtio-net-pci,netdev=n1"
    ] ++ pkgs.lib.optionals efi [ "-bios ${OVMF.fd}/FV/OVMF.fd" ]
    ++ pkgs.lib.optionals enableTpm [
      "-chardev"
      "socket,id=chrtpm,path=tpm.sock"
      "-tpmdev"
      "emulator,id=tpm0,chardev=chrtpm"
      "-device"
      "tpm-tis,tpmdev=tpm0"
    ] ++ extraFlags;

  tpmStartCommands = pkgs.lib.optionalString enableTpm ''
    mkdir -p tpmstate
    ${pkgs.swtpm}/bin/swtpm socket \
      --tpmstate dir=tpmstate \
      --ctrl type=unixio,path=tpm.sock &
  '';

  # Pass empty config file to prevent ssh from failing to create ~/.ssh
  sshOpts =
    "-F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=1";
  win-exec = pkgs.writeShellScriptBin "win-exec" ''
    set -e
    ${pkgs.sshpass}/bin/sshpass -p1234 -- \
      ${pkgs.openssh}/bin/ssh -np 2022 ${sshOpts} \
      ''${SSHUSER:-wfvm}@localhost \
      $1
  '';
  win-wait = pkgs.writeShellScriptBin "win-wait" ''
    set -e

    # If the machine is not up within 10 minutes it's likely never coming up
    timeout=600

    # Wait for VM to be accessible
    sleep 20
    echo "Waiting for SSH..."
    while true; do
      if test "$timeout" -eq 0; then
        echo "SSH connection timed out"
        exit 1
      fi

      output=$(${win-exec}/bin/win-exec 'echo|set /p="Ran command"' || echo "")
      if test "$output" = "Ran command"; then
        break
      fi

      echo "Retrying in 1 second, timing out in $timeout seconds"

      ((timeout=$timeout-1))

      sleep 1
    done
    echo "SSH OK"
  '';
  win-put = pkgs.writeShellScriptBin "win-put" ''
    set -e
    echo win-put $1 -\> $2
    ${pkgs.sshpass}/bin/sshpass -p1234 -- \
      ${pkgs.openssh}/bin/sftp -r -P 2022 ${sshOpts} \
      wfvm@localhost -b- << EOF
        cd $2
        put $1
    EOF
  '';
  win-get = pkgs.writeShellScriptBin "win-get" ''
    set -e
    echo win-get $1
    ${pkgs.sshpass}/bin/sshpass -p1234 -- \
      ${pkgs.openssh}/bin/sftp -r -P 2022 ${sshOpts} \
      wfvm@localhost:$1 .
  '';

  wfvm-run = { name, image, script, display ? false, isolateNetwork ? true
    , forwardedPorts ? [ ], fakeRtc ? true, qemu ? pkgs.qemu }:
    let
      restrict = if isolateNetwork then "on" else "off";
      # use socat instead of `tcp:...` to allow multiple connections
      guestfwds = builtins.concatStringsSep "" (map
        ({ listenAddr, targetAddr, port }:
          ",guestfwd=tcp:${listenAddr}:${
            toString port
          }-cmd:${pkgs.socat}/bin/socat\\ -\\ tcp:${targetAddr}:${
            toString port
          }") forwardedPorts);
      qemuParams = mkQemuFlags (pkgs.lib.optional (!display) "-display none"
        ++ pkgs.lib.optional (!fakeRtc) "-rtc base=localtime" ++ [
          "-drive"
          "file=${image},index=0,media=disk,cache=unsafe"
          "-snapshot"
          "-netdev user,id=n1,net=192.168.47.0/24,restrict=${restrict},hostfwd=tcp::2022-:22,hostfwd=tcp::55055-:55055,hostfwd=tcp::55056-:55056,hostfwd=udp::55055-:55055,hostfwd=udp::55056-:55056${guestfwds},hostfwd=tcp::55088-:55088,hostfwd=tcp::55089-:55089,hostfwd=tcp::55090-:55090,hostfwd=tcp::55091-:55091,hostfwd=tcp::55092-:55092,hostfwd=tcp::55093-:55093,hostfwd=tcp::55094-:55094,hostfwd=tcp::55095-:55095,hostfwd=tcp::55096-:55096,hostfwd=tcp::55097-:55097,hostfwd=tcp::55098-:55098,hostfwd=tcp::55099-:55099"
          #"-display default,show-cursor=on"
          "-display none"
        ]);
    in pkgs.writeShellScriptBin "wfvm-run-${name}" ''
      set -e -m
      ${tpmStartCommands}
      ${qemu}/bin/qemu-system-x86_64 ${
        pkgs.lib.concatStringsSep " " qemuParams
      } &

      export PATH=$PATH:${win-exec}/bin

      ${win-wait}/bin/win-wait

      ${script}

      echo "Shutting down..."
      ${win-exec}/bin/win-exec 'shutdown /s'
      echo "Waiting for VM to terminate..."
      fg
      echo "Done"
    '';
}
