# 通用滚轮缩放 · macOS

在支持原生缩放的 Mac 应用中，用 **Control（⌃）＋鼠标滚轮**放大、缩小内容。工具自动识别前台应用菜单中的缩放命令，调用应用自己的缩放功能；缩放档位、排版和记忆方式由各应用管理。

v1.1.0 从“Chrome 滚轮缩放”升级为“通用滚轮缩放”，支持发现 Chrome、Edge、VS Code、Codex 等应用的原生缩放菜单。豆包的“放大字体／缩小字体”作为该应用的专用适配处理。**未识别到缩放菜单的应用保持原有滚轮行为。**

## 下载与安装

前往 [Releases 下载页面](https://github.com/qinx555-cmyk/chrome-ctrl-scroll-zoom/releases/latest)，下载 `ScrollZoom-1.1.0-universal.dmg` 或 `.zip`。Universal 安装包包含 Apple Silicon（arm64）与 Intel（x86_64）版本，最低系统要求为 macOS 13。

1. 打开 `.dmg`，把“通用滚轮缩放”拖到 **Applications／应用程序**；也可解压 `.zip` 后复制应用。
2. 打开应用，点击“打开辅助功能设置”，启用“通用滚轮缩放”。系统可能要求本机账户验证。
3. 菜单栏出现 **⌃↕**。切换到目标应用，待菜单栏状态识别该应用后，按住 Control 滚动鼠标。

从 v1.0.0 升级时，先通过菜单栏退出“Chrome 滚轮缩放”，移除旧应用，再安装新应用；更新后可能需要重新开启辅助功能权限。如设置过登录项，也请改为新应用。详见[完整使用说明](docs/使用说明.md)。

应用采用本地 ad hoc 签名，**尚未取得 Apple Developer ID 签名和 Apple 公证**。首次打开提示的处理方式见[使用说明](docs/使用说明.md)及 [Apple 官方说明](https://support.apple.com/zh-cn/102445)。

## 操作

| 操作 | 效果 |
| --- | --- |
| Control＋滚轮向上 | 调用当前应用的放大命令 |
| Control＋滚轮向下 | 调用当前应用的缩小命令 |
| 松开 Control 再滚动 | 普通滚动 |
| 菜单栏 →“恢复当前应用默认缩放” | 调用当前应用自己的重置命令；部分应用没有此命令 |
| 点击菜单栏 ⌃↕ | 查看当前应用状态、暂停、反转方向、查看权限或退出 |

许多应用也支持 **⌘0** 重置缩放，以应用菜单显示的快捷键为准。默认不设置开机自启；重启后重新打开应用，或自行加入 macOS 登录项。

## 兼容性与隐私

- 自动识别应用菜单中成对的原生放大、缩小命令，并通过 macOS 辅助功能执行菜单动作。无对应命令、命令禁用或无法识别时，保持原有滚轮行为。
- 仅处理前台应用的 Control＋滚轮；同时按住 Command、Option 或 Shift 时保持原行为。切换应用后会重新检查菜单。
- 豆包的“放大字体／默认字体／缩小字体”仅作为豆包适配；不会把其他应用的任意字体大小命令当作通用缩放。
- 缩放范围由应用决定：浏览器通常缩放网页，编辑器可能缩放整个界面，豆包适配调整字体。应用未提供的缩放能力无法由本工具补齐。
- 普通触控板捏合保持原有行为；Control＋触控板滚动及连续滚轮采用累积阈值，并忽略惯性，设备手感可能不同。
- 不读取网页、聊天或文档正文，不记录输入事件，不联网。为识别能力，会读取前台应用的名称、进程信息和原生菜单的标题、层级、可用状态及动作。
- 辅助功能是 macOS 提供的较宽权限，上述使用范围由本项目代码实现。
- 如果 macOS 系统缩放也占用 Control＋滚轮，请调整系统缩放的修饰键，避免冲突。

## 从源码构建

需要安装 Xcode 或 Xcode Command Line Tools。应用无第三方运行依赖。

```sh
git clone https://github.com/qinx555-cmyk/chrome-ctrl-scroll-zoom.git
cd chrome-ctrl-scroll-zoom
chmod +x build.sh test.sh package.sh
./test.sh
./build.sh
./package.sh
```

产物位于 `dist/`：`通用滚轮缩放.app`、`ScrollZoom-1.1.0-universal.dmg`、`ScrollZoom-1.1.0-universal.zip` 和 `SHA256SUMS.txt`。安装包提供应用和中文使用说明，源码由 GitHub 的 Source code 下载项提供。构建脚本优先使用现有 Command Line Tools，否则使用所选 Xcode；不代为接受开发工具许可。

## 验证情况

- 53 项滚轮计算检查、38 项缩放策略检查通过。
- v1.1.0 用户实体鼠标验收通过：Edge、VS Code、豆包、Codex 四个应用均可用 Control＋滚轮向上放大、向下缩小。其他应用及各应用的所有子界面未逐一验收。
- v1.0.0 曾在 Apple Silicon、macOS 27.0.1、Chrome 155.0.8059.84 上完成用户实体鼠标 Control＋滚轮放大和缩小验证。
- Intel 架构提供编译产物，未在 Intel Mac 实机运行；macOS 13～26、所有应用版本、PDF 及不同鼠标驱动未逐一验证。

更多内容：[中文使用说明](docs/使用说明.md) · [v1.1.0 版本说明](docs/版本说明-v1.1.0.md) · [v1.0.0 历史版本说明](docs/版本说明-v1.0.0.md)
