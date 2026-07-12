# CodexUsageBar

[简体中文](README.md) | [English](README.en.md)

一款轻量、本机运行的 macOS 菜单栏应用，让你像查看电量一样，一眼看到 Codex 剩余用量。

## 下载

**[直接下载 v0.1.1（macOS Apple Silicon）](https://github.com/ShaneD711/CodexUsageBar/releases/download/v0.1.1/CodexUsageBar-v0.1.1-macos-arm64.zip)**

[SHA-256 校验文件](https://github.com/ShaneD711/CodexUsageBar/releases/download/v0.1.1/CodexUsageBar-v0.1.1-macos-arm64.zip.sha256) · [查看全部版本](https://github.com/ShaneD711/CodexUsageBar/releases)

> `v0.1.1` 是未经 Apple 公证的预览版，仅支持 Apple Silicon 和 macOS 14 及以上版本。首次打开需要在“系统设置 > 隐私与安全性”中手动允许。

## 为什么做这个应用

在 Codex 中查看剩余用量，需要打开侧边栏，点击最下方的用户名，再点击“剩余用量”。对于经常关注 Token 消耗的用户，这段重复操作既打断工作，也会放大用量焦虑。

CodexUsageBar 把 5 小时剩余百分比和重置时间直接放到 Mac 菜单栏。无需离开当前工作，只要抬眼看一下，就能知道还剩多少用量。

## 使用效果

### 菜单栏一眼查看

直接显示 5 小时窗口的剩余百分比和重置时间，无需再打开 Codex 设置页面。

<img src="docs/images/menu-bar-usage.png" alt="CodexUsageBar 菜单栏剩余用量" width="132">

### 点击查看完整用量

点击菜单栏即可查看 5 小时和 1 周两个用量窗口。

<img src="docs/images/usage-popover.png" alt="CodexUsageBar 用量详情面板" width="320">

## 功能

- 菜单栏常驻显示 5 小时剩余百分比和重置时间。
- 点击后查看 5 小时和 1 周剩余用量。
- 启动、打开面板、每 5 分钟以及 Mac 唤醒后自动刷新。
- 刷新失败时保留上一次成功数据，超过 10 分钟会显示过期警告。
- 界面跟随 macOS 使用简体中文或英文，并区分未安装、未登录和读取超时等问题。
- 弹出面板使用紧凑单行标题，以及 macOS 系统字体、字重、控件尺寸和布局间距。
- 可在 Finder 中定位当前运行的应用副本，并复制不含账号和用量数据的脱敏诊断信息。
- 本机读取、本机缓存，不上传用量或对话数据。

## 安装

1. 下载并解压 `CodexUsageBar-v0.1.1-macos-arm64.zip`。
2. 将 `CodexUsageBar.app` 移动到“应用程序”文件夹。
3. 尝试打开一次 CodexUsageBar。
4. 打开 `系统设置 > 隐私与安全性`，找到 CodexUsageBar 并点击“仍要打开”。
5. 确认系统警告，然后在 Mac 顶部菜单栏找到 CodexUsageBar。

公司或学校管理的 Mac 可能禁止手动放行。新下载的版本也可能需要重新批准。决定是否继续前，可以阅读 [Apple 关于打开未知开发者应用的说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)。

### 验证下载文件

将 ZIP 和校验文件放在同一个文件夹，然后运行：

```bash
shasum -a 256 -c CodexUsageBar-v0.1.1-macos-arm64.zip.sha256
```

预期输出：

```text
CodexUsageBar-v0.1.1-macos-arm64.zip: OK
```

### 卸载

退出 CodexUsageBar，将 `/Applications/CodexUsageBar.app` 移到废纸篓。如需同时清除本地缓存，运行：

```bash
defaults delete com.shaned.CodexUsageBar
```

## 开发

要求：macOS 14 或更高版本、Xcode 16 或更高版本，以及已安装并登录的 ChatGPT/Codex。

项目使用 Swift、SwiftUI 和 Swift Package Manager，不依赖第三方库。

```bash
# 构建并启动开发版本
./script/build_and_run.sh

# 运行测试
swift test

# 生成 Release 安装包（版本读取自 VERSION）
./script/package_release.sh
```

## 隐私

CodexUsageBar 只在本机请求和缓存剩余用量。它不会读取对话内容，不会读取 `~/.codex/auth.json`，也不会上传任何用量数据。

## 许可证

CodexUsageBar 使用 [MIT License](LICENSE) 开源。

## 免责声明

这是一个非官方本机工具，不隶属于 OpenAI。Codex 的本机接口未来可能随版本更新而变化。
