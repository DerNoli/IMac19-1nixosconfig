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

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

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

# services.kdeconnect.enable = false;

  # ============================================================
  # AUDIO
  # ============================================================

  services.pulseaudio.enable = false;

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;

    pulse.enable = true;
  };

  # ============================================================
  # PRINTING
  # ============================================================

  services.printing.enable = true;

  # ============================================================
  # USER APPS & Cusomizations
  # ============================================================

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
      mangohud
      protonup-qt
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
      lutris
      heroic
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

environment.systemPackages = with pkgs; [mangohud protonup-qt lutris bottles heroic
];

  # ============================================================
  # FLATPAK ENABLED
  # ============================================================

services.flatpak.enable = true;

  # ============================================================
  # DEACTIVATE HIBERNATE AND SLEEP
  # ============================================================


systemd.sleep.settings.Sleep = {
  AllowHibernation = "no";
  AllowHybridSleep = "no";
  AllowSuspend = "no";
  AllowSuspendThenHibernate = "no";
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
# nupdate ZUM VOLLSTÄNDIGEN UPDATEN
# ============================================================


nix.settings.experimental-features = [ "nix-command" "flakes" ];

environment.shellAliases = {
  nupdate = "sudo nix flake update --flake /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos";
};


hardware.bluetooth = {
  enable = true;
  powerOnBoot = true;
  settings = {
    General = {
      # Shows battery charge of connected devices on supported
      # Bluetooth adapters. Defaults to 'false'.
      Experimental = true;
      # When enabled other devices can connect faster to us, however
      # the tradeoff is increased power consumption. Defaults to
      # 'false'.
      FastConnectable = true;
    };
    Policy = {
      # Enable all controllers when they are found. This includes
      # adapters present on start as well as adapters that are plugged
      # in later on. Defaults to 'true'.
      AutoEnable = true;
    };
  };
};
# ============================================================
# NIXOS VERSION
# ============================================================

  system.stateVersion = "26.05";
