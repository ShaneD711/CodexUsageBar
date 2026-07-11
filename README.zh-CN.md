# CodexUsageBar

[English](README.md) | [简体中文](README.zh-CN.md)

一款轻量、本机、极简的 macOS 菜单栏应用，用来一眼查看 Codex 剩余用量。

## 核心想法

CodexUsageBar 的目标是让用户像查看 Mac 电量一样查看 Codex 剩余用量。

菜单栏 MVP 显示：

```text
75% 16:57
```

含义：

- `75%`：Codex 5 小时窗口的剩余用量。
- `16:57`：Codex 5 小时窗口的重置时间。

点击菜单栏后显示：

```text
剩余用量
5 小时    75%   16:57
1 周      97%   7月18日
```

## MVP 边界

第一版只做：

- 只支持 Codex。
- 菜单栏显示 5 小时剩余百分比和重置时间。
- 点击后显示 5 小时和 1 周两个窗口。
- 显示刷新状态和清晰的失败状态。
- 通过 Codex 本机 app-server 读取数据。

第一版不做：

- Token 总量统计。
- Token 活动热力图。
- 插件排行。
- Skill 使用统计。
- 今日任务看板。
- Claude Code 支持。
- 账号切换。
- 完整 dashboard 主窗口。
- 云同步。
- 读取 `~/.codex/auth.json`。
- 上传任何使用数据。

## 数据来源

使用 Codex 本机 app-server 的 JSON-RPC 协议：

```text
codex app-server
account/rateLimits/read
```

应用只读取 rate limit 数据，不上传 usage 数据。

## 当前状态

第一版可运行 MVP 已经完成：

- 菜单栏显示 5 小时剩余百分比和重置时间。
- 百分比和重置时间作为一段固定宽度的菜单栏标签显示，避免重置时间被系统压缩隐藏。
- 点击后显示 5 小时和 1 周用量。
- 启动、打开弹窗和每 5 分钟自动刷新。
- Mac 从睡眠中唤醒后立即刷新。
- 读取失败时保留上一次成功数据。
- 数据超过 10 分钟未成功刷新时，菜单栏和弹窗显示过期警告。
- 已加入 JSON-RPC 返回值解析测试。

设计文档：

- [MVP 设计文档](docs/superpowers/specs/2026-07-11-codex-usage-menu-bar-design.zh-CN.md)
- [MVP design specification](docs/superpowers/specs/2026-07-11-codex-usage-menu-bar-design.md)
- [未公证预览版发布设计](docs/superpowers/specs/2026-07-11-unnotarized-preview-release-design.zh-CN.md)
- [Unnotarized preview release design](docs/superpowers/specs/2026-07-11-unnotarized-preview-release-design.md)

## 下载与安装

`v0.1.0` 是面向 macOS 14 或更高版本的**未经 Apple 公证的 Apple Silicon 预览版**。它没有使用 Apple Developer ID 签名，也没有经过 Apple 公证。

1. 打开 [GitHub Releases](https://github.com/ShaneD711/CodexUsageBar/releases)，下载 `CodexUsageBar-v0.1.0-macos-arm64.zip`。
2. 解压 ZIP，将 `CodexUsageBar.app` 移动到“应用程序”文件夹。
3. 尝试打开一次 CodexUsageBar。
4. 打开 `系统设置 > 隐私与安全性`，找到被阻止的 CodexUsageBar，然后点击“仍要打开”。
5. 再次确认警告，并在系统要求时输入 Mac 登录密码。

公司或学校管理的 Mac 可能禁止手动放行。下载新版本后，也可能需要重新批准。决定是否继续前，可以阅读 [Apple 关于打开未知开发者应用的说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)。

### 验证下载文件

将 `.zip` 和 `.sha256` 文件下载到同一个文件夹，然后运行：

```bash
shasum -a 256 -c CodexUsageBar-v0.1.0-macos-arm64.zip.sha256
```

预期输出：

```text
CodexUsageBar-v0.1.0-macos-arm64.zip: OK
```

### 卸载

退出 CodexUsageBar，将 `/Applications/CodexUsageBar.app` 移到废纸篓。如需同时清除上一次用量快照缓存，运行：

```bash
defaults delete com.shaned.CodexUsageBar
```

## 开发环境

- macOS 14 或更高版本。
- Xcode 16 或更高版本。
- 本机已安装并登录 ChatGPT/Codex。

项目使用 Swift、SwiftUI 和 Swift Package Manager，不依赖第三方库。

## 使用 Xcode 运行

1. 打开 Xcode。
2. 选择 `File > Open`。
3. 选择项目根目录中的 `Package.swift`。
4. 在顶部 Scheme 中选择 `CodexUsageBar` 和 `My Mac`。
5. 点击运行按钮，或按 `Command + R`。

应用运行后不会显示主窗口或 Dock 图标，请在 Mac 顶部菜单栏查看。

## 使用终端运行

构建、生成本地 `.app` 并启动：

```bash
./script/build_and_run.sh
```

运行测试：

```bash
swift test
```

构建后的本地应用位于：

```text
dist/CodexUsageBar.app
```

## 应用图标

仓库中保留的图标资源位于：

```text
Sources/CodexUsageBar/Resources/AppIcon.png
Sources/CodexUsageBar/Resources/AppIcon.icns
```

可以通过以下命令根据代码定义的设计重新生成两个文件：

```bash
swift script/generate_app_icon.swift
```

如果缺少 `AppIcon.icns`，构建脚本会输出清晰错误并终止，避免再次打包出空白应用图标。

## 隐私

CodexUsageBar 只通过本机 `codex app-server` 请求 rate limit 数据。它不会读取 `~/.codex/auth.json`，不会读取对话内容，也不会上传用量数据。

## 许可证

CodexUsageBar 使用 [MIT License](LICENSE) 开源。

## 免责声明

这是一个非官方的本机工具，不隶属于 OpenAI。它使用 Codex 本机 app-server 协议，该协议未来可能随着 Codex 更新而变化。
