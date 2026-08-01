# we-layerd-flake

[we-layerd](https://github.com/Aromatic05/we-layerd) 的 Nix Flake 打包，包含 [DirectX Shader Compiler](https://github.com/microsoft/DirectXShaderCompiler) (DXC)。

## 包含内容

- **we-layerd** — 基于 Rust 的 Wallpaper Engine Wayland 原生运行时，支持 layer-shell
- **we-gui** — 基于 iced 的图形界面，用于浏览创意工坊壁纸和配置生成
- **DXC** — 微软官方 DirectX Shader 编译器（v1.9.2602.24），用于渲染 Wallpaper Engine 着色器
- GStreamer 全插件、CEF 浏览器引擎（151.0.7922.72）、Vulkan、PipeWire 音频

> CEF 版本说明：nixpkgs 默认的 CEF 149.0.5（Chromium 149）在 NVIDIA 显卡的 OSR
> 共享纹理模式下无法初始化 SkSurface（CEF issue #3953 / Electron issue #49247，
> NVIDIA GBM 拒绝 `SCANOUT_CPU_READ_WRITE` backbuffer）。本 flake 固定使用
> 151.0.7922.72（Chromium 151，含 2025-08 合并的 NVIDIA 修复 CL 6681354）。

## 安装

### 1. 在 flake.nix 中引入

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    we-layerd.url = "github:yigexuanmu/we-layerd-flake";
  };

  outputs = { self, nixpkgs, we-layerd, ... } @ inputs: {
    # ...
  };
}
```

### 2. 安装到系统

**NixOS systemPackages**

```nix
environment.systemPackages = [
  inputs.we-layerd.packages.x86_64-linux.default
];
```

**Home Manager**

```nix
home.packages = [
  inputs.we-layerd.packages.x86_64-linux.default
];
```

## 配置

从示例配置开始：

```bash
cp config.example.toml ~/.config/we-layerd/config.toml
```

关键配置项：

| 字段 | 说明 |
|------|------|
| `renderer.library_path` | 留空 `""` 启用自动查找 |
| `renderer.source` | Steam 创意工坊壁纸路径，如 `/path/to/Steam/steamapps/workshop/content/431960/<wallpaper-id>` |
| `renderer.assets_path` | Wallpaper Engine 资源路径，如 `/path/to/Steam/steamapps/common/wallpaper_engine/assets` |
| `renderer.cache_path` | 渲染缓存路径，默认 `~/.cache/we-layerd/renderer` |

完整配置模型请参考：[CONFIGURATION.md](https://github.com/Aromatic05/we-layerd/blob/main/docs/CONFIGURATION.md)

## 使用

```bash
# 启动 GUI 界面
we-gui

# 或直接运行守护进程
we-layerd run --config ~/.config/we-layerd/config.toml
```

## 依赖

- NixOS（Wayland 会话）
- NVIDIA 或 Mesa Vulkan 驱动
- PipeWire / PulseAudio 音频服务
