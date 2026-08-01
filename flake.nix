{
  description = "we-layerd — Wallpaper Engine runtime for Linux Wayland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      dxc = pkgs.callPackage ./dxc.nix {};

      # CEF 149.0.5 (Chromium 149) cannot initialize SkSurface on NVIDIA GPUs
      # in OSR shared-texture mode (CEF issue #3953 / Electron issue #49247:
      # NVIDIA GBM rejects BufferUsage::SCANOUT_CPU_READ_WRITE backbuffers).
      # Chromium 151 (CEF 151.3.14) does NOT actually fix it either (CEF
      # issue #3953 is still open); the working workaround is the
      # WE_WEB_FORCE_SOFTWARE_PAINT renderer patch in we-layerd.nix, which
      # forces the web backend into software painting while keeping DMA-BUF
      # for the scene/video backends.
      cef-binary = pkgs.cef-binary.override {
        version = "151.3.14";
        gitRevision = "5d67476";
        chromiumVersion = "151.0.7922.72";
        srcHashes = {
          x86_64-linux = "sha256-JtRCtGIXxW0dkq5p+oxkfxQQcWpWNLvON3gf1eludbU=";
        };
      };

      we-layerd = pkgs.callPackage ./we-layerd.nix {
        inherit dxc cef-binary;
      };
    in
    {
      packages.${system} = {
        inherit dxc we-layerd;
        default = we-layerd;
      };
    };
}
