# we-layerd-flake

[we-layerd](https://github.com/Aromatic05/we-layerd) 的 Nix Flake 打包，包含 [DirectX Shader Compiler](https://github.com/microsoft/DirectXShaderCompiler) (DXC)。

## 包含内容

- **we-layerd** — 基于 Rust 的 Wallpaper Engine Wayland 原生运行时，支持 layer-shell
- **we-gui** — 基于 iced 的图形界面，用于浏览创意工坊壁纸和配置生成
- **DXC** — 微软官方 DirectX Shader 编译器（v1.9.2602.24），用于渲染 Wallpaper Engine 着色器
- GStreamer 全插件、CEF 浏览器引擎（151.0.7922.72）、Vulkan、PipeWire 音频

> CEF 版本说明：本 flake 固定使用 CEF 151.3.14（Chromium 151.0.7922.72）。
> NVIDIA 上存在已知限制：CEF 的 OSR 共享纹理（web 壁纸的 DMA-BUF 导出路径）
> 在 NVIDIA GBM 后端上无法初始化 SkSurface（CEF issue #3953，Chromium 将
> `SCANOUT_CPU_READ_WRITE` 映射为 `GBM_BO_USE_LINEAR|SCANOUT|TEXTURING`，
> NVIDIA 不支持；Chromium 151 与 main 分支均未修复）。因此 NVIDIA 上
> web 壁纸必须走软件绘制路径，见下文「NVIDIA 显卡」一节。
> **注意：本 flake 不强制 NVIDIA 用户全局关闭 DMA-BUF（prefer_dmabuf=false
> 会让 scene/video 壁纸掉到 9-13 FPS），而是只对 web 后端启用软件绘制。**

## NVIDIA 显卡

CEF 的 OSR 共享纹理在 NVIDIA GBM 后端上无法初始化 SkSurface（见上），
导致 web 壁纸在 NVIDIA 上黑屏/失败。本 flake 通过补丁让 web 后端支持
软件绘制开关：

- 设置环境变量后重启 we-layerd：
  ```bash
  export WE_WEB_FORCE_SOFTWARE_PAINT=1
  we-gui
  ```
- 仅影响 web 壁纸：scene/video 壁纸继续使用 DMA-BUF 硬件路径，不受影响。
- 如果 web 壁纸在软件绘制下仍卡顿，可额外尝试：
  ```bash
  export WE_CEF_EXTRA_SWITCHES="--disable-gpu-compositing"
  ```
  并在 `config.toml` 中调低 `renderer.fps`（如 30）。

## 系统音频采集

本 flake 为 we-layerd 附加了 PipeWire 系统音频采集补丁（上游 we-layerd
本身没有任何音频通路）：we-layerd 通过 PipeWire 监听默认输出的 monitor，
把系统正在播放的声音以 f32 交错采样转发给渲染器，使音频响应型壁纸
（scene/web）随音乐律动。视频后端不接受音频推送，自动跳过采集；
非音频响应型 web 壁纸不受影响。

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
