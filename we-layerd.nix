{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  pkg-config,
  wrapGAppsHook3,
  wayland,
  wayland-protocols,
  wayland-scanner,
  libxkbcommon,
  gtk3,
  vulkan-loader,
  vulkan-headers,
  mesa,
  libGL,
  gst_all_1,
  lz4,
  pango,
  fontconfig,
  freetype,
  libva,
  libdrm,
  glib,
  libx11,
  git,
  cef-binary,
  dxc,
  zlib,
  alsa-lib,
  pulseaudio,
  pipewire,
  openssl,
  xdotool,
  libappindicator-gtk3,
  patchelf,
  gcc,
  libclang,
  glibc,
  version ? "0.2.6",
}:

let
  src = fetchFromGitHub {
    owner = "Aromatic05";
    repo = "we-layerd";
    rev = "9da371f519d1cfcf61980e1d1927f8a3bbff2742";
    hash = "sha256-oExBFgNzQMa36OnejgyYtpTnLytyj3lTE1M+0QKgn/M=";
    fetchSubmodules = true;
  };
in
rustPlatform.buildRustPackage {
  pname = "we-layerd";
  inherit version src;

  cargoLock.lockFile = ./we-layerd-audio.lock;

  cargoBuildFlags = ["--workspace"];

  nativeBuildInputs = [
    cmake
    pkg-config
    wrapGAppsHook3
    git
    wayland-scanner
    patchelf
    libclang
  ];

  buildInputs = [
    wayland
    wayland-protocols
    libxkbcommon
    gtk3
    vulkan-loader
    vulkan-headers
    mesa
    libGL
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-ugly
    lz4
    pango
    fontconfig
    freetype
    libva
    libdrm
    glib
    libx11
    cef-binary
    dxc
    zlib
    alsa-lib
    pulseaudio
    pipewire
    pipewire.dev
    openssl
    xdotool
    libappindicator-gtk3
  ];

  postPatch = ''
    # Replace the upstream Cargo.lock with ours: the generated lockfile adds
    # pipewire and bumps a few transitive deps, and nixpkgs'
    # cargoSetupPostPatchHook requires source Cargo.lock == vendored lock.
    cp ${./we-layerd-audio.lock} Cargo.lock
    # System audio capture for audio-reactive wallpapers: we-layerd has no
    # audio pipeline at all upstream, so add a PipeWire capture thread that
    # forwards interleaved f32 samples to the renderer via
    # we_session_push_audio_samples (scene + web backends react; the video
    # backend rejects pushes).
    git apply ${./we-layerd-audio.patch}
    sed -i '/fn ensure_recursive_submodules/,/^}/c\fn ensure_recursive_submodules(_upstream_root: \&Path) {}\n' build.rs
    sed -i '/target_include_directories(we-cef-helper/a\        ''${_CEF_ROOT}' third_party/wallpaper-engine-renderer/src/backend/web/CMakeLists.txt
    # Patch OnBeforeCommandLineProcessing to apply GL/GPU switches to ALL
    # processes (not just the browser process). The upstream code returns
    # early for subprocesses assuming they "inherit" switches, but
    # --use-gl and --use-angle are NOT inherited by GPU/renderer
    # subprocesses, causing "gl=none,angle=none" errors.
    sed -i 's|// Only tweak the browser process command line. Renderer / utility|// Apply GL/GPU switches to ALL processes (browser + renderer + GPU).|' third_party/wallpaper-engine-renderer/src/backend/web/internal/cef/helper/AppHandler.cpp
    sed -i '/helpers inherit the relevant switches from the browser anyway\./d' third_party/wallpaper-engine-renderer/src/backend/web/internal/cef/helper/AppHandler.cpp
    sed -i '/if (! process_type.empty()) return;/d' third_party/wallpaper-engine-renderer/src/backend/web/internal/cef/helper/AppHandler.cpp
    # NVIDIA: CEF shared textures (the web backend's DMA-BUF export path) fail
    # to initialize SkSurface on the NVIDIA GBM backend (CEF issue #3953,
    # unfixed in Chromium 151 and main). Force software paint for the web
    # backend only via WE_WEB_FORCE_SOFTWARE_PAINT=1, keeping DMA-BUF for the
    # scene/video backends. Both reset sites of m_forceSoftwarePaint in load()
    # and start() read the env var instead of hardcoding false.
    sed -i 's|m_forceSoftwarePaint[[:space:]]*=[[:space:]]*false;|m_forceSoftwarePaint = std::getenv("WE_WEB_FORCE_SOFTWARE_PAINT") != nullptr;|g' third_party/wallpaper-engine-renderer/src/backend/web/internal/WebBackend.cpp
  '';

  preConfigure = ''
    export CMAKE_MODULE_PATH="${cef-binary}/cmake:$CMAKE_MODULE_PATH"
    export CEF_ROOT="${cef-binary}"
    export HANABI_DXC_ROOT="${dxc}"
    export LIBCLANG_PATH="${libclang.lib}/lib"
    export C_INCLUDE_PATH="${glibc.dev}/include"
    export NIX_CFLAGS_COMPILE="''${NIX_CFLAGS_COMPILE:-} -I${libdrm.dev}/include/libdrm"
  '';

  postInstall = ''
    mkdir -p $out/lib
    cp target/we-renderer-upstream/install/lib/libwallpaper-engine-renderer.so $out/lib/
    cp target/we-renderer-upstream/install/lib/we-cef-helper $out/lib/ 2>/dev/null || true
    chmod 755 $out/lib/libwallpaper-engine-renderer.so

    # Patch we-cef-helper for NixOS - it's a raw CEF binary not patched for Nix
    chmod 755 $out/lib/we-cef-helper
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath "${cef-binary}/Release:${cef-binary}/Resources:${gcc.cc.lib}/lib:${lib.makeLibraryPath [
        zlib libdrm alsa-lib pulseaudio pipewire wayland libxkbcommon gtk3
        vulkan-loader mesa libGL glib libx11 pango fontconfig freetype libva
      ]}" \
      $out/lib/we-cef-helper || true

    # Create a unified CEF directory where libcef.so and icudtl.dat coexist.
    # CEF resolves DIR_MODULE to the directory containing libcef.so, then
    # looks for icudtl.dat in that same directory. In cef-binary, libcef.so
    # is in Release/ but icudtl.dat is in Resources/ - they never meet.
    # By symlinking both into one directory and making LD_LIBRARY_PATH find
    # libcef.so there first, DIR_MODULE resolves to our directory and
    # CEF finds icudtl.dat right next to it.
    mkdir -p $out/lib/cef
    ln -s ${cef-binary}/Release/libcef.so $out/lib/cef/
    ln -s ${cef-binary}/Release/libEGL.so $out/lib/cef/
    ln -s ${cef-binary}/Release/libGLESv2.so $out/lib/cef/
    # Do NOT symlink libvulkan.so.1 / libvk_swiftshader.so / vk_swiftshader_icd.json
    # here - they would shadow the real NVIDIA Vulkan driver because this directory
    # is first in LD_LIBRARY_PATH. CEF disables Vulkan via --use-vulkan=disabled.
    ln -s ${cef-binary}/Release/v8_context_snapshot.bin $out/lib/cef/
    ln -s ${cef-binary}/Resources/icudtl.dat $out/lib/cef/
    ln -s ${cef-binary}/Resources/chrome_100_percent.pak $out/lib/cef/
    ln -s ${cef-binary}/Resources/chrome_200_percent.pak $out/lib/cef/
    ln -s ${cef-binary}/Resources/resources.pak $out/lib/cef/
    ln -s ${cef-binary}/Resources/locales $out/lib/cef/

    # Install we-gui binary
    cp target/release/we-gui $out/bin/we-gui 2>/dev/null || true
    chmod 755 $out/bin/we-gui 2>/dev/null || true

    # Install .desktop file
    mkdir -p $out/share/applications
    cat > $out/share/applications/we-gui.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=we-gui
Comment=Wallpaper Engine helper GUI for Linux
Exec=we-gui
Icon=we-gui
Terminal=false
Categories=Utility;Graphics;
StartupNotify=true
EOF
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --set CEF_ROOT ${cef-binary}
      --set WE_CEF_RESOURCES_DIR ${cef-binary}/Resources
      --set WE_CEF_LOCALES_DIR ${cef-binary}/Resources/locales
      --set WE_CEF_HELPER_PATH $out/lib/we-cef-helper
      --prefix LD_LIBRARY_PATH : $out/lib/cef:${lib.makeLibraryPath [
        zlib
        libdrm
        alsa-lib
        pulseaudio
        pipewire
        libappindicator-gtk3
        wayland
        libxkbcommon
        gtk3
        vulkan-loader
        mesa
        libGL
        glib
        libx11
        pango
        fontconfig
        freetype
        libva
      ]}
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${lib.makeSearchPath "lib/gstreamer-1.0" [
        gst_all_1.gstreamer
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-bad
        gst_all_1.gst-plugins-good
        gst_all_1.gst-plugins-ugly
        gst_all_1.gst-libav
      ]}
    )
  '';

  meta = with lib; {
    description = "A native Wallpaper Engine runtime for Linux Wayland";
    homepage = "https://github.com/Aromatic05/we-layerd";
    license = licenses.gpl3Plus;
    mainProgram = "we-layerd";
    longDescription = ''
      Includes:
      - we-layerd: Wallpaper Engine Wayland runtime
      - we-gui: GUI companion for workshop browsing
    '';
  };
}
