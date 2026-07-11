# CodexUsageBar MVP 设计文档

日期：2026-07-11

## 产品目标

开发一款极简 macOS 菜单栏应用，让 Codex 用户可以像查看 Mac 电量一样，一眼看到 Codex 剩余用量。

这款应用要解决的核心问题是：用户不需要再反复打开 Codex，点击侧边栏、个人资料或设置入口，再进入用量区域查看剩余额度。

## MVP 范围

MVP 只支持 Codex，不做主窗口 dashboard。

菜单栏默认显示：

```text
75% 16:57
```

含义：

- `75%`：Codex 5 小时窗口的剩余百分比。
- `16:57`：Codex 5 小时窗口的重置时间。

点击菜单栏后的第一屏：

```text
jiangjiang

剩余用量
5 小时    75%   16:57
1 周      97%   7月18日

刚刚刷新
```

应用应优先满足“扫一眼就知道”的体验。点击只是为了查看 1 周窗口和刷新状态。

## 明确不做

MVP 不包含：

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

使用 Codex 本机 app-server 的 JSON-RPC 协议，通过 stdio 通信：

1. 启动 `codex app-server`。
2. 发送 `initialize`，并设置 `capabilities.experimentalApi = true`。
3. 发送 `initialized`。
4. 调用 `account/rateLimits/read`。

优先读取 `rateLimitsByLimitId.codex`。如果没有该字段，则回退到 `rateLimits`。

窗口映射：

- `primary`：5 小时窗口。
- `secondary`：1 周窗口。

显示映射：

- 剩余百分比 = `100 - usedPercent`。
- 重置时间 = 格式化后的 `resetsAt`。
- 窗口名称 = 根据 `windowDurationMins` 转换为 `5 小时` 或 `1 周`。

## 刷新策略

应用应在以下时机刷新：

- 启动时刷新一次。
- 用户打开弹出面板时立即刷新。
- 后台定时刷新，默认可以先设为 5 分钟。
- 用户在弹出面板中手动点击刷新。

刷新过程中菜单栏不要闪烁。新的读取请求进行时，继续显示上一次成功读取的数据。

## 失败状态

失败状态要清晰，但不能打扰用户。

如果找不到 Codex：

```text
--% --
```

弹出面板提示：`未找到 Codex。请先安装或打开 ChatGPT/Codex。`

如果 Codex 未登录：

```text
--% --
```

弹出面板提示：`Codex 未登录。请打开 Codex 并登录。`

如果读取失败，但已有缓存数据：

```text
75% 16:57
```

弹出面板提示：`上次更新于 8 分钟前。本次刷新失败。`

如果读取失败，且没有缓存数据：

```text
--% --
```

弹出面板提示：`无法读取 Codex 用量。`

## 隐私模型

MVP 是本机应用。

应用应该：

- 启动或连接本机 Codex app-server。
- 只请求账号 rate limit 数据。
- 如需缓存，只保存上一次成功读取的展示快照。

应用不应该：

- 读取认证 token。
- 直接调用 ChatGPT 私有网页接口。
- 上传 usage 数据。
- 读取 session transcript。
- 解析 prompt 或 tool 内容。

## 开源定位

项目定位：

```text
一款轻量本机 macOS 菜单栏应用，用来一眼查看 Codex 剩余用量。
```

必须包含的免责声明：

```text
这是一个非官方的本机工具，不隶属于 OpenAI。它使用 Codex 本机 app-server 协议，该协议未来可能随着 Codex 更新而变化。
```

## 成功标准

MVP 成功的标准：

- 用户无需打开 Codex，就能看到 5 小时剩余用量和重置时间。
- 点击菜单栏后能看到 5 小时和 1 周两个窗口。
- 应用不读取 `auth.json`。
- 应用保持小巧，不演变成 usage analytics dashboard。
- 失败状态可理解，并在可能时保留上一次成功读取的数据。
