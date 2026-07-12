# CodexUsageBar

[简体中文](README.md) | [English](README.en.md)

一款轻量的 macOS 菜单栏应用，让你像查看电量一样，一眼看到 Codex 剩余用量。

## 下载

**[直接下载 v0.1.2（macOS Apple Silicon）](https://github.com/ShaneD711/CodexUsageBar/releases/download/v0.1.2/CodexUsageBar-v0.1.2-macos-arm64.zip)**

[SHA-256 校验文件](https://github.com/ShaneD711/CodexUsageBar/releases/download/v0.1.2/CodexUsageBar-v0.1.2-macos-arm64.zip.sha256) · [全部版本](https://github.com/ShaneD711/CodexUsageBar/releases)

需要 macOS 14 或更高版本、Apple Silicon Mac，以及已经安装并登录的 ChatGPT/Codex。

> 当前版本未经 Apple 公证。首次打开时，需要前往“系统设置 > 隐私与安全性”并选择“仍要打开”。

## 为什么需要它

在 Codex 中查看剩余用量，需要打开侧边栏，点击底部用户名，再点击“剩余用量”。对于经常关注 Token 消耗的用户，这段重复操作既打断工作，也会放大用量焦虑。

CodexUsageBar 把剩余百分比和重置时间直接放到 Mac 菜单栏。无需离开当前工作，抬眼就能看到。

## 使用效果

<p>
  <img src="docs/images/menu-bar-usage.png" alt="菜单栏剩余用量" width="132">
  &nbsp;&nbsp;
  <img src="docs/images/usage-popover.png" alt="用量详情" width="320">
</p>

## 功能

- 菜单栏直接显示剩余百分比和重置时间。
- 点击后查看完整用量。
- 自动刷新，并在数据过期或读取失败时给出提示。
- 支持简体中文和英文界面。
- 所有数据只在本机处理，不上传用量或对话内容。

## 安装

1. 下载并解压 ZIP 文件。
2. 将 `CodexUsageBar.app` 移到“应用程序”文件夹。
3. 尝试打开一次 CodexUsageBar。
4. 前往 `系统设置 > 隐私与安全性`，点击“仍要打开”。
5. 在 Mac 顶部菜单栏查看剩余用量。

公司或学校管理的 Mac 可能禁止手动放行。可参考 [Apple 的安全说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)。

## 隐私

CodexUsageBar 在本机读取并显示剩余用量，不读取对话内容，也不会上传用量数据。

## 卸载

先从菜单中退出 CodexUsageBar，再将“应用程序”文件夹中的 `CodexUsageBar.app` 移到废纸篓。

如需同时清除本地数据：

```bash
defaults delete com.shaned.CodexUsageBar
```

## 许可证

[MIT License](LICENSE) · 非 OpenAI 官方应用
