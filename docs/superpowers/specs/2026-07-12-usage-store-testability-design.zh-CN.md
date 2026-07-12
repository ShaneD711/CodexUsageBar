# UsageStore 可测试性设计

[English](2026-07-12-usage-store-testability-design.md) | [简体中文](2026-07-12-usage-store-testability-design.zh-CN.md)

日期：2026-07-12

## 问题

`UsageStore` 虽然允许传入 client 和 cache，但依赖具体类型，并在初始化时立即创建后台任务与系统唤醒监听。测试难以脚本化失败/成功顺序、阻塞读取、并发刷新和缓存状态。`CachedUsageStore` 固定使用 `UserDefaults.standard`，也无法隔离损坏缓存测试。

## 设计

- `CodexUsageReading` 定义一次异步快照读取。
- `UsageSnapshotCaching` 在 MainActor 上定义同步加载和保存快照，约束 UserDefaults 访问位置。
- `CodexAppServerClient` 与 `CachedUsageStore` 分别实现上述协议。
- `UsageStore` 依赖协议，并允许测试关闭自动启动及显式 `start/stop`。
- 可执行文件诊断回退使用可注入 resolver，避免测试读取开发机环境。
- `CachedUsageStore` 接受指定的 `UserDefaults` 和 key。
- `CancellationError` 不写入 `lastFailure`。

## 进程取消

`CodexAppServerClient` 为每次读取创建线程安全的进程控制器。父 Task 被取消时，控制器终止对应 app-server 子进程；Pipe 关闭使阻塞读取退出，client 最终抛出 `CancellationError`。

## 测试

- 缓存立即展示，后台成功后替换。
- 有缓存时刷新失败保留旧值并设置失败类别。
- 失败后成功清除失败并保存新快照。
- 并发刷新只调用一次读取器。
- Store 取消不产生用户错误。
- 损坏缓存返回 nil。
- 真实子进程提前退出立即返回 `connectionClosed`。
- 持续通知仍遵守总 deadline。
- 取消读取会真实终止子进程。

提前 EOF 表示服务退出，应映射为 `service-stopped`；`unsupported-response` 仅用于成功收到响应但结构无法解析的情况。
