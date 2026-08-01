{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation {
  pname = "directx-shader-compiler";
  version = "1.9.2602.24";

  src = fetchurl {
    url = "https://github.com/microsoft/DirectXShaderCompiler/releases/download/v1.9.2602.24/linux_dxc_2026_05_26.x86_64.tar.gz";
    hash = "sha256-kos+mYbRHcQnkFDgI0CVDCm8vR5e+5097ZZp2t43Y50=";
  };

  dontBuild = true;

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out
    cp -r bin $out/
    cp -r include $out/
    cp -r lib $out/
    chmod 755 $out/bin/dxc
    chmod 755 $out/lib/libdxcompiler.so
  '';

  meta = with lib; {
    description = "DirectX Shader Compiler";
    homepage = "https://github.com/microsoft/DirectXShaderCompiler";
    license = licenses.mit;
  };
}
