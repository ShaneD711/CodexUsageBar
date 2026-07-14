# Codex 协议兼容与异常处理设计

[English](2026-07-13-protocol-resilience-design.md) | [简体中文](2026-07-13-protocol-resilience-design.zh-CN.md)

## 目标

CodexUsageBar 必须优先展示已经验证过但明确标记为过期的旧快照，不能用含义不确定的新数据覆盖它。协议兼容属于数据正确性边界，而不是尽量解析的附加能力。

这是 `v0.2.1` 的 P0 正确性范围。本次改动加固现有 `account/read` 和 `account/rateLimits/read` 流程，不扩大产品的数据读取范围。

## 原则

- 忽略响应信封和业务对象中的未知字段。
- 只有在转换结果精确且没有歧义时，才接受标量字段的表示方式变化。
- 不伪造缺失的百分比、窗口时长、重置时间、账户状态或额度窗口。
- 选中的额度集合中，只要存在一个窗口的关键字段不可信，就拒绝整个新快照。
- 启动、传输、账户、服务端或解析失败时，都保留上一次成功快照。
- 不在应用状态和诊断信息中保存账户数据、服务端原始文案或响应正文。

## 协议请求

应用仍然只发送：

1. `initialize`
2. `initialized`
3. `account/read`
4. `account/rateLimits/read`

客户端继续为整个交换过程使用同一个单调时钟截止时间。不增加账户详情、会话、提示词、对话或 Token 历史接口。

## 账户状态校验

账户解析器只判断 `result` 是否存在、`account` 是否为 JSON 对象；只有不存在账户对象时，才要求 `requiresOpenaiAuth` 是有效布尔值。

| `account` JSON 状态 | `requiresOpenaiAuth` | 处理结果 |
| --- | --- | --- |
| 任意对象，包括 `{}` | 任意表示或缺失 | 继续读取额度 |
| `null` 或字段缺失 | `true` | 未登录 |
| `null` 或字段缺失 | `false` | 当前提供方不要求 OpenAI 登录，继续读取 |
| `null` 或字段缺失 | 缺失或类型错误 | 返回格式变化 |
| 字符串、数字、布尔值或数组 | 任意值 | 返回格式变化 |

应用不使用邮箱、套餐、工作区或凭据详情，因此接受未知账户类型和未知字段。空对象仍表示账户对象存在。存在账户对象时，`requiresOpenaiAuth` 的无关变化不会阻止额度读取。这需要自定义最小解码逻辑，不能继续依赖当前的 `AccountMarker` DTO。

## 额度集合选择

解析器按以下顺序选择 Codex 额度集合：

1. `rateLimitsByLimitId["codex"]`；
2. `rateLimitsByLimitId` 中内部 `limitId` 等于 `codex` 的对象；
3. 向后兼容的顶层 `rateLimits` 对象。

`limitId` 只接受大小写完全一致的 JSON 字符串 `"codex"`，不进行大小写归一化或标量转换。如果映射中有两个及以上对象在内部声明 `limitId == "codex"`，必须返回 `ambiguousCodexLimits`，不能依赖字典遍历顺序随意选择。

只有高优先级候选集合不存在时，才能向下回退。候选集合一旦被选中，验证失败就必须拒绝整个响应；不能绕过已经明确存在但损坏的 Codex 集合，改读低优先级的顶层对象。

解析器不能因为映射里只有一个对象，就假设它一定属于 Codex。如果没有 Codex 集合，也没有顶层兼容集合，则拒绝响应。

`primary` 和 `secondary` 是传输层来源位置，不代表固定名称，也不是领域模型不变量。解析器验证每个实际存在的传输窗口，按照 `[primary, secondary]` 的来源顺序收集完整窗口，并要求结果非空。然后归一化到现有领域模型：第一个收集到的窗口成为 `RateLimitSnapshot.primary`，第二个成为可选的 `secondary`。因此传输响应只有 `secondary` 时，会把该有效窗口提升为领域模型的 `primary`，不需要把领域字段改成可选值。

以下窗口组合都属于有效情况：

- 5 小时加 1 周；
- 只有 1 周；
- 只有 5 小时；
- 长短窗口顺序交换；
- 一到两个未知但为正数的窗口时长。

## 窗口关键字段

窗口键缺失或值为 `null` 时，表示该窗口不存在，允许继续。JSON 对象表示窗口存在，必须进行完整校验。数组、字符串、数字或布尔值出现在窗口位置时，返回 `invalidCriticalType`。空对象属于已存在但缺少关键字段。只有两个传输窗口都缺失或为 `null` 时，才返回 `noUsableWindow`。

每个实际存在的窗口都必须包含：

- `usedPercent`：有限且非负的数值；
- `windowDurationMins`：可以用 `Int` 表示的正整数；
- `resetsAt`：大于 0 且不超过 `Date.distantFuture.timeIntervalSince1970` 的整数 Unix 时间戳。

这些字段接受 JSON 数值，或者符合以下 JSON Number 语法的字符串：

```regex
-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?
```

当目标字段要求精确整数 300 时，接受 `"300"`、`"300.0"` 和 `"3e2"`；拒绝 `"+300"`、`" 300 "`、`"03"`、`"300_000"`、`"NaN"` 和 `"Infinity"`。整数校验前先解析为 `Decimal`，避免二进制浮点舍入把小数或溢出值错误地变成整数。使用 `JSONSerialization` 时必须先识别布尔类型，不能把底层 `NSNumber` 表示的 `true` 和 `false` 当成 1 和 0。

`windowDurationMins` 和 `resetsAt` 转换前必须是精确整数。重置时间上限用于拒绝被误当成秒的毫秒时间戳，并保证可以安全构造和格式化 `Date`。`usedPercent` 可以是小数，但转换后必须是有限且非负的 `Double`。

如果上游明确返回超过 100 的已用百分比，可以继续接受。`remainingPercent` 必须先用 `Double` 和 `0...100` 边界比较，进入范围后才能转换成 `Int`，避免 `Double.greatestFiniteMagnitude` 等极大有限值触发运行时错误。

只要一个已存在窗口缺少关键字段或字段值无效，就拒绝整个选中快照。不能静默丢弃该窗口，否则可能隐藏真实存在的额度限制。

## JSON-RPC 信封规则

行读取器必须在业务载荷解析前执行以下规则。

可以忽略：

- 没有 `id` 且 `method` 为字符串的合法 JSON 通知对象；
- 属于其他整数请求 ID 的合法 JSON 响应；
- 已知或未知的合法通知方法。

stdout 出现以下内容时，必须立即返回 `responseChanged(phase:reason:)`，原因为 `malformedEnvelope`：

- 非 JSON 行；
- 顶层不是 JSON 对象；
- 既不是通知也不是响应的对象；
- `id` 不是整数的响应；
- 当前请求响应同时包含 `result` 和 `error`；
- 当前请求响应既没有 `result` 也没有 `error`；
- 当前请求的 `error` 不是包含整数 `code` 的对象。

只有和当前 `initialize`、`account/read` 或 `account/rateLimits/read` 请求匹配的响应才映射为请求失败。`initialized` 是通知，不存在匹配响应。

## 错误模型

增加不包含原始数据的结构化解析原因：

```swift
enum ResponseChangeReason: String {
    case malformedEnvelope
    case missingResult
    case missingCodexLimits
    case ambiguousCodexLimits
    case missingCriticalField
    case invalidCriticalType
    case invalidCriticalValue
    case noUsableWindow
}
```

解析原因优先级固定为：

1. 无法形成合法 RPC 信封 -> `malformedEnvelope`；
2. 合法成功信封包含 `"result": null` -> `missingResult`；
3. 找不到 Codex 集合和顶层回退 -> `missingCodexLimits`；
4. 找到多个内部 Codex 集合 -> `ambiguousCodexLimits`；
5. 两个窗口都缺失或为 `null` -> `noUsableWindow`；
6. 已存在窗口缺少关键字段 -> `missingCriticalField`；
7. 关键字段使用不支持的 JSON 类型 -> `invalidCriticalType`；
8. 可以识别的标量值不合法 -> `invalidCriticalValue`。

稳定的用户错误类别包括：

- 未找到 Codex；
- 未登录；
- Codex 版本不兼容；
- 请求超时；
- Codex 服务意外停止；
- 返回格式变化；
- 启动失败；
- 服务暂时不可用。

固定协议请求收到 JSON-RPC `method not found`（`-32601`）或 `invalid params`（`-32602`）时，归类为 Codex 版本不兼容。其他 JSON-RPC 服务端错误归类为服务暂时不可用，只保留数字错误码。

`CodexAppServerError` 用 `incompatible(code:phase:)` 和 `responseChanged(phase:reason:)` 取代宽泛的 invalid-response 错误。`UsageFailure.Category` 增加对应的稳定 `incompatible` 和 `responseChanged` 类别，并保存可选的 `responseChangeReason`。JSON 无法解析、必要语义数据缺失或关键值无效都属于返回格式变化。

诊断信息可以包含类别、阶段、数字错误码和解析原因，但不能包含字段名称、原始文案、响应片段、账户数据、百分比或重置时间。

## 可用状态与缓存

`UsageAvailability` 增加独立的返回格式变化状态，不再和版本不兼容、服务暂时不可用混为一类。可用状态表示当前可以展示什么；`UsageFailure` 表示最近一次刷新为什么失败，两者不能合并。

没有历史快照时，弹窗显示准确的稳定错误类别。有历史快照时，继续显示该快照，并根据原始 `fetchedAt` 判断是否过期；弹窗同时显示本次刷新失败原因，必要时再显示过期警告。

解析失败不能写入 `UserDefaults`，也不能清除上一次成功快照。

缓存数据不能因为符合 `Codable` 就被直接信任。`RateLimitSnapshot` 提供共享语义不变量，校验每个窗口的有限非负用量、正数时长、可表示的正数重置时间，以及不会溢出的剩余量计算。从缓存解码的快照必须通过同一领域不变量才能展示；不合法缓存需要从 `UserDefaults` 删除并按无缓存处理。

## 真实响应样本

脱敏 JSON 样本放在 `Tests/CodexUsageBarTests/Fixtures`，通过 `Bundle.module` 读取。`Package.swift` 必须为测试 Target 声明 `.process("Fixtures")`。样本保留真实响应信封和字段结构，但必须替换账户标识、邮箱、百分比、时间戳和其他用户数据。

必须包含：

- 历史的 5 小时加 1 周双窗口响应；
- 当前只有 1 周的响应；
- 顶层 `rateLimits` 兼容响应；
- 已登录和未登录账户响应；
- 包含额外未知字段的响应。

使用表格化合成测试覆盖 Free、Go、Plus、Pro、Pro Lite、Team、Business、Enterprise、Edu 和 unknown 等套餐标识。套餐值不能参与额度窗口选择或修改。

样本中不能包含服务端原始错误文案、Token、账户 ID、真实邮箱或直接复制的个人额度数值。

## 自动化测试

测试覆盖：

- 上述账户状态表中的每一种情况；
- 精确键名和内部 ID 两种 Codex 集合定位、内部 ID 歧义、已选高优先级集合损坏时禁止回退，以及只有高优先级不存在时才能使用顶层回退；
- 只有 1 周、只有短窗口、只有 secondary 时提升、双窗口、顺序交换和未知时长；
- 未知字段不影响解析；
- 完整的数字字符串接受和拒绝语法；
- 关键字段缺失、格式错误、含义不明确、负数、小数和溢出；
- `usedPercent` 为 101、1,000,000 和 `Double.greatestFiniteMagnitude` 时安全返回 0，不发生运行时错误；
- 秒与毫秒重置时间戳以及可表示日期上限；
- 损坏 RPC 行和当前 ID 信封冲突立即失败，而不是等待超时；
- 方法不存在和参数无效导致的版本不兼容；
- 服务端临时错误、超时、EOF、取消和启动失败；
- 解析失败后保留缓存和失败上下文；
- 可以解码但语义无效的缓存被删除并忽略；
- 后续成功响应替换缓存并清除错误；
- 诊断信息只包含安全的类别、阶段、错误码和解析原因。

## 文档同步

`ARCHITECTURE.md` 补充保守解析边界，`SECURITY.md` 补充真实样本脱敏规则，并明确失败响应不会被持久化。面向普通用户的 README 继续保持极简，不展示协议实现细节。

## 不在本次范围

- 直接调用 OpenAI HTTP API；
- 读取 `auth.json`、会话、提示词、对话或项目数据；
- 展示套餐名称或账户身份；
- 部分展示格式已经损坏的额度快照；
- 自动从用户真实账户捕获测试样本；
- 长连接 app-server 或订阅额度更新通知。

## 验收标准

`v0.2.1` 完成时，所有受支持响应结构都能产生正确归一化窗口；超大百分比不会触发运行时错误；损坏信封立即失败；含义不明确的关键变化和无效缓存永远不会成为展示数据；用户能够区分要求中的每一种错误且诊断不包含原始数据；Fixture 已正确配置并完成脱敏；完整 Swift 测试和 arm64 Release 构建全部通过。
