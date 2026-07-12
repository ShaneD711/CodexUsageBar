# Codex app-server 请求时限设计

[English](2026-07-12-app-server-deadline-design.md) | [简体中文](2026-07-12-app-server-deadline-design.zh-CN.md)

日期：2026-07-12

## 问题

旧实现为每次读取 stdout 行重新创建 15 秒超时。持续出现的无关 JSON-RPC 通知可以不断延长请求；初始化和额度读取也各自可能消耗完整超时。当 stdout 已关闭且缓冲区为空时，读取器无法立即区分 EOF 和暂时无数据，导致已退出的服务被误报为超时。

## 设计

- 在 app-server 成功启动后使用 `DispatchTime` 创建一次 15 秒单调时钟 deadline。
- 初始化响应和 `account/rateLimits/read` 响应共享同一个 deadline。
- `readResponse` 跳过无关消息时继续传递原 deadline，不重新计时。
- `readResponse` 在处理每一行之前主动检查 deadline，即使缓冲区持续有数据也必须按时终止。
- 行读取器区分行数据、等待数据和 EOF。
- stdout 关闭且缓冲区为空时立即返回 EOF。
- EOF 映射为独立的 `service-stopped` 失败，不映射为超时或不兼容响应。

## 验证

- 测试无关通知使用完全相同的 deadline。
- 测试 deadline 已过且缓冲区仍有消息时立即超时。
- 测试 EOF 被映射为服务退出。
- 使用真实 `Pipe` 验证关闭写端后读取器在 0.5 秒内返回 EOF。
- 现有解析、错误、本地化、诊断和版本测试继续通过。
