{
  description =
    "NixOS for iMac19,1 with Apple SMC fan control, Davidjo CS8409 audio, automatic brightness, and Affinity V3";

  inputs = {

    # ============================================================
    # NIXOS STABLE
    # ============================================================

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # ============================================================
    # DAVIDJO APPLE CS8409 HDA DRIVER
    # ============================================================

    snd-hda-macbookpro = {
      url = "github:davidjo/snd_hda_macbookpro";
      flake = false;
    };

    # ============================================================
    # IMAC AUTOMATIC BRIGHTNESS DAEMON
    # ============================================================

    imac-brightness = {
      url = "github:DerNoli/imac_brightness";
      flake = false;
    };



    # ============================================================
    # AFFINITY NIX
    # ============================================================

    affinity-nix.url = "github:mrshmllow/affinity-nix";
  };

  outputs = {
    self,
    nixpkgs,
    snd-hda-macbookpro,
    imac-brightness,
    affinity-nix,
  }:

  let

    system = "x86_64-linux";


qwenTTS = pkgs.python3Packages.buildPythonPackage {
  pname = "qwen3-tts";
  version = "0.1.2";

  src = pkgs.fetchPypi {
    pname = "qwen3-tts";
    version = "0.1.2";
    sha256 = "e0a0e035889cc88cff8c8f2ccb249246e0e2b3b77135c3e6d720b1fb69885129";
  };

  propagatedBuildInputs = with pkgs.python3Packages; [
    numpy
    soundfile
    torch
  ];
};




    # ==========================================================
    # BASE PACKAGE SET
    #
    # Used for custom derivations below.
    #
    # The NixOS module later receives its own `pkgs` argument,
    # which includes the Affinity overlay.
    # ==========================================================

    pkgs = import nixpkgs {
      inherit system;

      config.allowUnfree = true;
    };

    # ==========================================================
    # KERNEL
    # ==========================================================

    kernelPackages = pkgs.linuxPackages_latest;
    kernel = kernelPackages.kernel;

    # ==========================================================
    # DAVIDJO CS8409 DRIVER
    # ==========================================================

    sndHdaMacbookPro =
      pkgs.stdenv.mkDerivation {
        pname = "snd-hda-codec-cs8409-davidjo";
        version = "unstable";

        src = snd-hda-macbookpro;

        nativeBuildInputs = with pkgs; [
          gnumake
          patch
          gcc
          binutils
          perl
        ];

        dontConfigure = true;

        buildPhase = ''
          runHook preBuild

          echo "=========================================="
          echo "Building Davidjo CS8409 driver"
          echo "Kernel version: ${kernel.version}"
          echo "Kernel modDirVersion: ${kernel.modDirVersion}"
          echo "=========================================="

          mkdir -p build

          # ------------------------------------------------------
          # Extract sound/hda from EXACT NixOS kernel source
          # ------------------------------------------------------

          tar \
            -xf ${kernel.src} \
            --strip-components=2 \
            -C build \
            linux-${kernel.version}/sound/hda

          # ------------------------------------------------------
          # Save original kernel Makefiles
          # ------------------------------------------------------

          mv build/hda/Makefile \
            build/hda/Makefile.orig

          mv build/hda/common/Makefile \
            build/hda/common/Makefile.orig

          mv build/hda/codecs/Makefile \
            build/hda/codecs/Makefile.orig

          mv build/hda/codecs/cirrus/Makefile \
            build/hda/codecs/cirrus/Makefile.orig

          # ------------------------------------------------------
          # Install Davidjo Makefiles
          # ------------------------------------------------------

          cp makefiles/Makefile \
            build/hda/Makefile

          cp makefiles/Makefile_common \
            build/hda/common/Makefile

          cp makefiles/Makefile_codecs \
            build/hda/codecs/Makefile

          cp makefiles/Makefile_cirrus \
            build/hda/codecs/cirrus/Makefile

          # ------------------------------------------------------
          # Apple / Cirrus support files
          # ------------------------------------------------------

          cp patch_cirrus/cirrus_apple.h \
            build/hda/codecs/cirrus/

          cp patch_cirrus/patch_cirrus_boot84.h \
            build/hda/codecs/cirrus/

          cp patch_cirrus/patch_cirrus_new84.h \
            build/hda/codecs/cirrus/

          cp patch_cirrus/patch_cirrus_real84.h \
            build/hda/codecs/cirrus/

          cp patch_cirrus/patch_cirrus_hda_generic_copy.h \
            build/hda/codecs/cirrus/

          cp patch_cirrus/patch_cirrus_real84_i2c.h \
            build/hda/codecs/cirrus/

          # ------------------------------------------------------
          # Apply Davidjo patches
          # ------------------------------------------------------

          cd build/hda

          patch -p1 < ../../patch_cs8409.c.diff
          patch -p1 < ../../patch_cs8409.h.diff

          cd ../..

          # ------------------------------------------------------
          # Build module against EXACT NixOS kernel
          # ------------------------------------------------------

          make \
            -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
            M=$PWD/build/hda \
            CFLAGS_MODULE="-DAPPLE_PINSENSE_FIXUP -DAPPLE_CODECS -DCONFIG_SND_HDA_RECONFIG=1 -Wno-unused-variable -Wno-unused-function" \
            modules

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p \
            $out/lib/modules/${kernel.modDirVersion}/updates

          cp \
            build/hda/codecs/cirrus/snd-hda-codec-cs8409.ko \
            $out/lib/modules/${kernel.modDirVersion}/updates/

          runHook postInstall
        '';

        meta = {
          description = "Davidjo Apple CS8409 HDA codec driver";
          homepage = "https://github.com/davidjo/snd_hda_macbookpro";
          license = pkgs.lib.licenses.gpl2;
          platforms = pkgs.lib.platforms.linux;
        };
      };

    # ==========================================================
    # APPLE SMC FAN CONTROLLER
    # ==========================================================

    macfan =
      pkgs.writeShellApplication {
        name = "macfan";

        runtimeInputs = with pkgs; [
          coreutils
          gnugrep
          gawk
        ];

        text = ''
          set -u

          # ------------------------------------------------------
          # Apple SMC path
          # ------------------------------------------------------

          SMC="/sys/devices/platform/applesmc.768"

          FAN_MANUAL="$SMC/fan1_manual"
          FAN_OUTPUT="$SMC/fan1_output"
          FAN_MIN="$SMC/fan1_min"
          FAN_MAX="$SMC/fan1_max"

          # ------------------------------------------------------
          # Requested logarithmic fan curve
          #
          # 45°C ->  500 RPM
          # 80°C -> 4000 RPM
          #
          # Below 45°C:
          #   500 RPM
          #
          # Above 80°C:
          #   4000 RPM
          # ------------------------------------------------------

          FAN_MIN_TEMP=45
          FAN_MAX_TEMP=80

          FAN_MIN_RPM=500
          FAN_MAX_RPM=4000

          FAN_LOG_STEEPNESS=4

          # ------------------------------------------------------
          # Check Apple SMC
          # ------------------------------------------------------

          if [ ! -d "$SMC" ]; then
            echo "ERROR: Apple SMC not found: $SMC" >&2
            exit 1
          fi

          for FILE in \
            "$FAN_MANUAL" \
            "$FAN_OUTPUT" \
            "$FAN_MIN" \
            "$FAN_MAX"
          do
            if [ ! -e "$FILE" ]; then
              echo "ERROR: required SMC file not found: $FILE" >&2
              exit 1
            fi
          done

          # ------------------------------------------------------
          # Read REAL Apple SMC fan limits
          # ------------------------------------------------------

          SMC_MIN_RPM="$(cat "$FAN_MIN")"
          SMC_MAX_RPM="$(cat "$FAN_MAX")"

          if ! printf '%s\n' "$SMC_MIN_RPM" \
            | grep -q '^[0-9][0-9]*$'
          then
            echo "ERROR: invalid SMC minimum RPM: $SMC_MIN_RPM" >&2
            exit 1
          fi

          if ! printf '%s\n' "$SMC_MAX_RPM" \
            | grep -q '^[0-9][0-9]*$'
          then
            echo "ERROR: invalid SMC maximum RPM: $SMC_MAX_RPM" >&2
            exit 1
          fi

          # ------------------------------------------------------
          # Find CPU/GPU temperature sensors
          # ------------------------------------------------------

          CPU_TEMP=""
          GPU_TEMP=""

          for label in "$SMC"/temp*_label; do
            [ -f "$label" ] || continue

            VALUE="$(cat "$label" 2>/dev/null || true)"
            INPUT="''${label%_label}_input"

            case "$VALUE" in

              *CPU*|*Cpu*|*cpu*)
                if [ -r "$INPUT" ]; then
                  CPU_TEMP="$INPUT"
                fi
                ;;

              *GPU*|*Gpu*|*gpu*)
                if [ -r "$INPUT" ]; then
                  GPU_TEMP="$INPUT"
                fi
                ;;

            esac
          done

          # ------------------------------------------------------
          # Fallback sensors for iMac 19,1
          # ------------------------------------------------------

          if [ -z "$CPU_TEMP" ] \
            && [ -r "$SMC/temp7_input" ]
          then
            CPU_TEMP="$SMC/temp7_input"
          fi

          if [ -z "$GPU_TEMP" ] \
            && [ -r "$SMC/temp25_input" ]
          then
            GPU_TEMP="$SMC/temp25_input"
          fi

          # ------------------------------------------------------
          # Make sure at least one sensor exists
          # ------------------------------------------------------

          if [ -z "$CPU_TEMP" ] && [ -z "$GPU_TEMP" ]; then
            echo "ERROR: no Apple SMC temperature sensors found." >&2
            echo "SMC directory: $SMC" >&2
            exit 1
          fi

          echo "=========================================="
          echo "iMac 19,1 Apple SMC fan controller"
          echo "=========================================="
          echo "SMC:          $SMC"
          echo "CPU sensor:   ''${CPU_TEMP:-none}"
          echo "GPU sensor:   ''${GPU_TEMP:-none}"
          echo "Fan:          $FAN_OUTPUT"
          echo "SMC min:      $SMC_MIN_RPM RPM"
          echo "SMC max:      $SMC_MAX_RPM RPM"
          echo "Curve min:    $FAN_MIN_RPM RPM"
          echo "Curve max:    $FAN_MAX_RPM RPM"
          echo "Curve temp:   $FAN_MIN_TEMP-''${FAN_MAX_TEMP}°C"
          echo "Log strength: $FAN_LOG_STEEPNESS"
          echo "=========================================="

          # ------------------------------------------------------
          # Clamp to REQUESTED curve limits
          # ------------------------------------------------------

          clamp_rpm() {
            local VALUE="$1"

            if [ "$VALUE" -lt "$FAN_MIN_RPM" ]; then
              VALUE="$FAN_MIN_RPM"
            fi

            if [ "$VALUE" -gt "$FAN_MAX_RPM" ]; then
              VALUE="$FAN_MAX_RPM"
            fi

            printf '%s\n' "$VALUE"
          }

          # ------------------------------------------------------
          # Cleanup
          # ------------------------------------------------------

          cleanup() {
            if [ -w "$FAN_MANUAL" ]; then
              printf '%s\n' 0 > "$FAN_MANUAL" 2>/dev/null || true
            fi
          }

          trap cleanup EXIT
          trap 'exit 0' SIGTERM SIGINT

          # ------------------------------------------------------
          # Check write permissions
          # ------------------------------------------------------

          if [ ! -w "$FAN_MANUAL" ]; then
            echo "ERROR: fan1_manual is not writable." >&2
            ls -l "$FAN_MANUAL" >&2 || true
            exit 1
          fi

          if [ ! -w "$FAN_OUTPUT" ]; then
            echo "ERROR: fan1_output is not writable." >&2
            ls -l "$FAN_OUTPUT" >&2 || true
            exit 1
          fi

          # ------------------------------------------------------
          # Enable manual fan control
          # ------------------------------------------------------

          printf '%s\n' 1 > "$FAN_MANUAL"

          LAST_RPM=0

          # ------------------------------------------------------
          # Main control loop
          # ------------------------------------------------------

          while true; do

            CPU=0
            GPU=0

            # ----------------------------------------------------
            # Read CPU temperature
            # ----------------------------------------------------

            if [ -n "$CPU_TEMP" ] && [ -r "$CPU_TEMP" ]; then

              CPU_RAW="$(
                cat "$CPU_TEMP" 2>/dev/null \
                || printf '%s\n' 0
              )"

              if printf '%s\n' "$CPU_RAW" \
                | grep -q '^[0-9][0-9]*$'
              then
                CPU=$((CPU_RAW / 1000))
              fi

            fi

            # ----------------------------------------------------
            # Read GPU temperature
            # ----------------------------------------------------

            if [ -n "$GPU_TEMP" ] && [ -r "$GPU_TEMP" ]; then

              GPU_RAW="$(
                cat "$GPU_TEMP" 2>/dev/null \
                || printf '%s\n' 0
              )"

              if printf '%s\n' "$GPU_RAW" \
                | grep -q '^[0-9][0-9]*$'
              then
                GPU=$((GPU_RAW / 1000))
              fi

            fi

            # ----------------------------------------------------
            # Validate temperatures
            # ----------------------------------------------------

            if [ "$CPU" -lt 0 ] || [ "$CPU" -gt 120 ]; then
              CPU=0
            fi

            if [ "$GPU" -lt 0 ] || [ "$GPU" -gt 120 ]; then
              GPU=0
            fi

            # ----------------------------------------------------
            # Use hottest sensor
            # ----------------------------------------------------

            if [ "$CPU" -gt "$GPU" ]; then
              TEMP="$CPU"
            else
              TEMP="$GPU"
            fi

            # ----------------------------------------------------
            # LOGARITHMIC FAN CURVE
            # ----------------------------------------------------

            if [ "$TEMP" -le "$FAN_MIN_TEMP" ]; then

              RPM="$FAN_MIN_RPM"

            elif [ "$TEMP" -ge "$FAN_MAX_TEMP" ]; then

              RPM="$FAN_MAX_RPM"

            else

              RPM="$(
                awk \
                  -v temp="$TEMP" \
                  -v min_temp="$FAN_MIN_TEMP" \
                  -v max_temp="$FAN_MAX_TEMP" \
                  -v min_rpm="$FAN_MIN_RPM" \
                  -v max_rpm="$FAN_MAX_RPM" \
                  -v k="$FAN_LOG_STEEPNESS" \
                  'BEGIN {
                    x = (temp - min_temp) / (max_temp - min_temp)

                    if (x < 0)
                      x = 0

                    if (x > 1)
                      x = 1

                    y = log(1 + k * x) / log(1 + k)

                    rpm = min_rpm + (max_rpm - min_rpm) * y

                    printf "%d\n", rpm + 0.5
                  }'
              )"

            fi

            # ----------------------------------------------------
            # Clamp to requested 500-4000 RPM range
            # ----------------------------------------------------

            RPM="$(clamp_rpm "$RPM")"

            # ----------------------------------------------------
            # Only write when RPM changes
            # ----------------------------------------------------

            if [ "$RPM" -ne "$LAST_RPM" ]; then

              printf '%s\n' "$RPM" > "$FAN_OUTPUT"

              LAST_RPM="$RPM"

              echo \
                "CPU=''${CPU}°C GPU=''${GPU}°C -> fan=''${RPM} RPM"

            fi

            sleep 2

          done
        '';
      };

    # ==========================================================
    # IMAC AUTOMATIC BRIGHTNESS
    # ==========================================================

    imacBrightnessPython =
      pkgs.python3.withPackages (pythonPackages: [
        pythonPackages.dbus-python
      ]);

    imacBrightness =
      pkgs.stdenvNoCC.mkDerivation {
        pname = "imac-brightness";
        version = "1.1";

        src = imac-brightness;

        dontConfigure = true;
        dontBuild = true;

        installPhase = ''
          mkdir -p "$out/bin"

          cp autobrightness.py "$out/bin/autobrightness"

          sed -i \
            "1c#!${imacBrightnessPython}/bin/python3" \
            "$out/bin/autobrightness"

          chmod 0755 "$out/bin/autobrightness"
        '';

        meta = {
          description =
            "Automatic iMac brightness control using the ambient light sensor";

          homepage =
            "https://github.com/DerNoli/imac_brightness";

          platforms =
            pkgs.lib.platforms.linux;
        };
      };

  in
  {
    # ==========================================================
    # NIXOS CONFIGURATION
    # ==========================================================

    nixosConfigurations.nixos =
      nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [

          ./hardware-configuration.nix
          ./configuration.nix

          # ====================================================
          # HARDWARE / SERVICES
          # ====================================================

          ({ pkgs, ... }: {

            # ==================================================
            # AFFINITY V3
            #
            # IMPORTANT:
            # This `pkgs` is the NixOS module package set,
            # not the manually imported pkgs from the let block.
            # Therefore the affinity-nix overlay is applied here.
            # ==================================================

            nixpkgs.overlays = [
              affinity-nix.overlays.default
            ];

            environment.systemPackages = [
              pkgs.affinity-v3
            ];

            # ==================================================
            # KERNEL
            # ==================================================

            boot.kernelPackages = kernelPackages;

            # ==================================================
            # IIO / AMBIENT LIGHT SENSOR
            # ==================================================

            hardware.sensor.iio.enable = true;

            # ==================================================
            # KERNEL MODULES
            # ==================================================

            boot.kernelModules = [
              "applesmc"
              "kvm-intel"
              "snd_hda_intel"
              "snd_hda_codec_cs8409"
            ];

            # ==================================================
            # DAVIDJO CS8409 DRIVER
            # ==================================================

            boot.extraModulePackages = [
              sndHdaMacbookPro
            ];

            # ==================================================
            # IMAC BRIGHTNESS CONFIGURATION
            # ==================================================

            environment.etc."autobrightness.conf".text = ''
              {
                "backlight_device": "acpi_video0",
                "ema_alpha": 0.02,
                "min_brightness": 0.30,
                "max_lux": 1500
              }
            '';

            # ==================================================
            # APPLE SMC FAN CONTROLLER
            # ==================================================

            systemd.services.macfan = {

              description =
                "iMac 19,1 Apple SMC Fan Controller";

              wantedBy = [
                "multi-user.target"
              ];

              after = [
                "systemd-modules-load.service"
              ];

              wants = [
                "systemd-modules-load.service"
              ];

              serviceConfig = {

                Type = "simple";

                ExecStart =
                  "${macfan}/bin/macfan";

                User = "root";
                Group = "root";

                Restart = "on-failure";
                RestartSec = 5;

                PrivateDevices = false;

                ProtectSystem = false;

                ProtectKernelTunables = false;

                ProtectKernelModules = false;

                ProtectControlGroups = false;

                ExecStartPre =
                  "${pkgs.coreutils}/bin/sleep 2";

                ExecStopPost =
                  "${pkgs.bash}/bin/bash -c 'if [ -w /sys/devices/platform/applesmc.768/fan1_manual ]; then printf 0 > /sys/devices/platform/applesmc.768/fan1_manual || true; fi'";
              };
            };

            # ==================================================
            # IMAC AUTOMATIC BRIGHTNESS SERVICE
            # ==================================================

            systemd.services.imac-brightness = {

              description =
                "iMac Automatic Ambient Light Brightness";

              wantedBy = [
                "multi-user.target"
              ];

              after = [
                "systemd-modules-load.service"
              ];

              wants = [
                "systemd-modules-load.service"
              ];

              serviceConfig = {

                Type = "simple";

                ExecStart =
                  "${imacBrightness}/bin/autobrightness";

                User = "root";
                Group = "root";

                Restart = "always";
                RestartSec = 3;

                ProtectSystem = false;
                ProtectKernelTunables = false;

                StandardOutput = "journal";
                StandardError = "journal";
              };
            };

          })
        ];
      };
  };
}
