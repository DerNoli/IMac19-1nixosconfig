{ config, pkgs, ... }:

{
  # ============================================================
  # BOOT + FIXES
  # ============================================================

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.plymouth.enable = true;
  boot.plymouth.theme = "nixos-bgrt";
  boot.plymouth.themePackages = [ pkgs.nixos-bgrt-plymouth ];

  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;

  boot.kernelParams = [
    "quiet"
    "intel_iommu=on"
    "iommu=pt"
    "pcie_ports=compat"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];

  # ============================================================
  # NETWORK
  # ============================================================

networking.networkmanager = {
  enable = true;
  plugins = with pkgs; [
    networkmanager-vpnc
    # add others if needed, e.g.:
    # networkmanager-openvpn
    networkmanager-openconnect
    # networkmanager-l2tp
    # networkmanager-strongswan
  ];
};
  # ============================================================
  # TIME / LOCALE
  # ============================================================

  time.timeZone = "Europe/Vienna";

  i18n.defaultLocale = "de_AT.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_AT.UTF-8";
    LC_IDENTIFICATION = "de_AT.UTF-8";
    LC_MEASUREMENT = "de_AT.UTF-8";
    LC_MONETARY = "de_AT.UTF-8";
    LC_NAME = "de_AT.UTF-8";
    LC_NUMERIC = "de_AT.UTF-8";
    LC_PAPER = "de_AT.UTF-8";
    LC_TELEPHONE = "de_AT.UTF-8";
    LC_TIME = "de_AT.UTF-8";
  };

  # ============================================================
  # KDE
  # ============================================================

  services.displayManager.plasma-login-manager.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "at";
    variant = "";
  };

  systemd.user.services."kscreen-5k" = {
    description = "Set 5K mode on login";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "/run/current-system/sw/bin/kscreen-doctor output.eDP-1.mode.19";
    };
  };

  virtualisation.waydroid.enable = true;
  virtualisation.waydroid.package = pkgs.waydroid-nftables;
  networking.nftables.enable = true;


nixpkgs.config.permittedInsecurePackages = [
  "NetworkManager-vpnc-1.4.0"
];


  # ============================================================
  # AUDIO (KORREKT FÜR NIXOS 26.05)
  # ============================================================

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;

    pulse.enable = true;

    wireplumber.enable = true;
  };

  # ============================================================
  # PRINTING
  # ============================================================

  services.printing.enable = true;

  # ============================================================
  # USER APPS & CUSTOMIZATIONS
  # ============================================================

services.ollama = {
  enable = true;
  package = pkgs.ollama-vulkan;

  loadModels = [
    "qwen3:8b"
  ];
};

services.open-webui = {
  enable = true;
};


  users.users.martink = {
    isNormalUser = true;
    description = "Martin Knoflach";

    extraGroups = [
      "networkmanager"
      "wheel"
    ];

    packages = with pkgs; [
      lm_sensors
      teams-for-linux
      fastfetch
      kdePackages.kdenlive
      vlc
      ffmpeg
      libreoffice-fresh
      hunspell
      hunspellDicts.de_DE
      keepassxc
      audacity
      ollama
      mangohud
      networkmanager-openconnect
      lutris
      bottles
      heroic
      vulkan-tools
      mesa-demos
      clinfo
      libva-utils
      davinci-resolve
      appimage-run
      localsend
      btop
      thunderbird
      gimp
      resources
      discord
      nixos-artwork.wallpapers.catppuccin-mocha
      facetimehd-firmware
      facetimehd-calibration
      kdePackages.kcalc
      speechd
      espeak-ng
      protontricks
      winetricks
      cabextract
      p7zip
      unzip
      wget
      kdePackages.kscreen
      piper-tts
      sox
      wl-clipboard
      anydesk
      rustdesk
      teamviewer
      signal-desktop
      openconnect
      networkmanagerapplet    
      omnissa-horizon-client
];
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      fetch --frames 60
    '';
  };

  # ============================================================
  # FIREFOX
  # ============================================================

  programs.firefox.enable = true;


virtualisation.libvirtd.enable = true;
programs.virt-manager.enable = true;


  # ============================================================
  # UNFREE
  # ============================================================

  nixpkgs.config.allowUnfree = true;

  # ============================================================
  # BROADCOM FIRMWARE
  # ============================================================

  hardware.firmware = [
    (pkgs.stdenvNoCC.mkDerivation {
      pname = "brcm-firmware";
      version = "1";
      src = ./firmware/brcm;

      installPhase = ''
        mkdir -p $out/lib/firmware/brcm
        cp -r $src/* $out/lib/firmware/brcm/
      '';
    })
  ];

  # ============================================================
  # MOUNT MY DRIVE
  # ============================================================

  fileSystems."/home/martink/Datengrab" = {
    device = "/dev/disk/by-uuid/df76625a-25f9-4926-b441-c110f812ad7b";
    fsType = "btrfs";
  };

  # ============================================================
  # GAMING ACTIVATION
  # ============================================================

  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    mangohud
    protonup-qt
    lutris
    bottles
    heroic
  ];

  # ============================================================
  # FLATPAK ENABLED
  # ============================================================

  services.flatpak.enable = true;

# ============================================================
# DEACTIVATE HIBERNATE AND SLEEP (KORREKT FÜR 26.05)
# ============================================================

systemd.sleep.settings = {
  Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };
};

  # ============================================================
  # AMD GPU / GRAPHICS
  # ============================================================

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    extraPackages = with pkgs; [
      mesa.opencl
    ];
  };

  environment.variables = {
    RUSTICL_ENABLE = "radeonsi";
  };

  # ============================================================
  # APPLE BACKLIGHT SENSOR
  # ============================================================

  hardware.sensor.iio.enable = true;

  # ============================================================
  # NUPDATE
  # ============================================================

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.shellAliases = {
    update = "sudo nix flake update --flake /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos";
      vpn = "nmcli connection up \"Neue Verbindung vpn\" --ask";
      vpn-off = "nmcli connection down \"Neue Verbindung vpn\"";

  # NixOS generations
  nix-gens = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
  nix-clean = "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +2 && sudo nix-collect-garbage -d";
  };


  # ============================================================
  # BLUETOOTH (KORREKT FÜR NIXOS 26.05)
  # ============================================================

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;

    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  programs.nix-ld.enable = true;

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

networking.firewall.enable = true;

networking.firewall = {
  allowedTCPPorts = [ 80 8080 443 ];
  allowedUDPPortRanges = [ { from = 4000; to = 4007; } ];
};
networking.firewall.trustedInterfaces = [ "virbr0" ];

  # ============================================================
  # NIXOS VERSION
  # ============================================================

  system.stateVersion = "26.05";
}
