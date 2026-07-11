# CodexUsageBar

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

MVP 设计文档位于：

```text
docs/superpowers/specs/2026-07-11-codex-usage-menu-bar-design.md
```

## 免责声明

这是一个非官方的本机工具，不隶属于 OpenAI。它使用 Codex 本机 app-server 协议，该协议未来可能随着 Codex 更新而变化。
