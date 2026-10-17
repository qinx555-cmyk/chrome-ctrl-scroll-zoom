# Chrome 滚轮缩放 · macOS

在 Mac 的 Google Chrome 中，用 **Control（⌃）＋鼠标滚轮**放大、缩小页面，沿用 Chrome 自己的缩放档位、页面排版和网站缩放记忆。

这是一个轻量的菜单栏应用，界面为中文，只在 **Google Chrome 稳定版位于前台**时处理滚轮。

## 下载与安装

前往 [Releases 下载页面](https://github.com/qinx555-cmyk/chrome-ctrl-scroll-zoom/releases/latest)，下载 `.dmg` 或 `.zip`。Universal 安装包包含 Apple Silicon（arm64）与 Intel（x86_64）版本，最低系统要求为 macOS 13。

1. 打开 `.dmg`，把“Chrome 滚轮缩放”拖到 **Applications／应用程序**；也可解压 `.zip` 后复制应用。
2. 打开应用，点击“打开辅助功能设置”，启用“Chrome 滚轮缩放”。系统可能要求本机账户验证。
3. 菜单栏出现 **⌃↕**，状态显示“已启用”后，在 Chrome 中按住 Control 滚动鼠标。

应用采用本地 ad hoc 签名，**尚未取得 Apple Developer ID 签名和 Apple 公证**。下载后可能出现首次打开提示；具体操作见[完整使用说明](docs/使用说明.md)。Apple 官方说明见[安全地打开 Mac 上的 App](https://support.apple.com/zh-cn/102445)。

## 操作

| 操作 | 效果 |
| --- | --- |
| Control＋滚轮向上 | 放大页面 |
| Control＋滚轮向下 | 缩小页面 |
| 松开 Control 再滚动 | 普通页面滚动 |
| ⌘0 | 恢复 Chrome 默认缩放比例 |
| 点击菜单栏 ⌃↕ | 暂停、反转方向、查看权限或退出 |

默认不设置开机自启；重启后重新打开应用，或自行加入 macOS 登录项。

## 隐私与兼容性

- 不读取网页内容、不记录输入事件、不联网。
- 只订阅 Quartz 滚轮事件，依据修饰键状态和前台应用决定是否处理，仅向 Chrome 进程发送原生缩放快捷键。
- 辅助功能是 macOS 提供的较宽权限，上述使用范围由本项目代码实现。
- 普通触控板捏合保持原有行为；连续滚轮及 Control＋触控板滚动采用累积阈值，手感可能与不同 Windows 驱动有所差异。
- 仅适配稳定版 Chrome，不处理 Safari、Edge、Chrome Beta 或 Canary。
- 如果系统“使用滚动手势配合修饰键缩放”也占用 Control，请调整系统缩放修饰键。
- Chrome 本身禁止缩放的界面仍遵循浏览器限制。PDF 由查看器处理缩放，尚未单独验收。

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

产物位于 `dist/`：Universal 应用、DMG、ZIP 和 `SHA256SUMS.txt`。安装包提供应用和中文使用说明，源码由 GitHub 的 Source code 下载项提供。构建脚本优先使用现有 Command Line Tools，否则使用所选 Xcode；不代为接受开发工具许可。

## 验证情况

- 53 项滚轮计算行为检查通过。
- Apple Silicon、macOS 27.0.1、Chrome 155.0.8059.84 实机验证：原生快捷键缩放、普通滚动，以及用户实体鼠标 Control＋滚轮放大和缩小。
- Intel 架构提供编译产物，未在 Intel Mac 实机运行；macOS 13～26、其他键盘布局、PDF 及不同鼠标驱动未逐一验证。

更多内容：[中文使用说明](docs/使用说明.md) · [v1.0.0 版本说明](docs/版本说明-v1.0.0.md)

实现入口：`Sources/main.swift` 处理菜单、权限和事件路由；`Sources/ScrollQuantizer.swift` 处理滚轮档位。
