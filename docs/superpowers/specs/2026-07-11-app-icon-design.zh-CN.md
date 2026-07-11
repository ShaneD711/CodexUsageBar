# CodexUsageBar 应用图标设计

[English](2026-07-11-app-icon-design.md) | [简体中文](2026-07-11-app-icon-design.zh-CN.md)

日期：2026-07-11

## 目标

为 macOS 应用补充完整图标，替换当前空白图标。图标应体现 Codex 的两个用量窗口，同时避免看起来像电池监控器或数据分析 dashboard。

这次修改影响 Finder 图标、显示简介面板和应用包元数据，不改变菜单栏文字，也不在用量百分比旁增加常驻图形。

## 已选方向

最终采用 Apple 原生风格第二轮中的第三个方案：**Usage Window（用量窗口）**。

图标包含：

- 浅灰白色 macOS 圆角方形底板。
- 石墨色工具窗口轮廓。
- 窗口内两条紧凑状态线。
- 蓝色主状态线，代表 5 小时用量窗口。
- 中性灰色次状态线，代表 1 周用量窗口。
- 两个小型石墨色窗口控制点。

图标不使用字母、数字、百分比、电池、仪表盘，也不复制 OpenAI 或 Apple 的品牌图形。

## 视觉参数

- 底板：`#FBFBFC`。
- 底板边框：`#D5D8DD`。
- 窗口轮廓：`#30343A`。
- 主用量状态线：`#2F7EE6`。
- 次用量状态线：`#B0B5BC`。
- 底板外区域：透明。

阴影保持柔和克制。图标在 Finder 的浅色和深色外观中都必须清晰。

## 资源要求

- 创建 `1024 x 1024` 主 PNG。
- 圆角底板外保留透明区域。
- 从主图生成 macOS 标准 iconset 尺寸。
- 将 iconset 打包为 `AppIcon.icns`。
- 最终资源存放在 `Sources/CodexUsageBar/Resources/AppIcon.icns`。

仓库同时保留最终 `.icns` 和用于重新生成它的主 PNG。

## 构建接入

更新 `script/build_and_run.sh`：

1. 要求 `Sources/CodexUsageBar/Resources/AppIcon.icns` 必须存在。
2. 图标缺失时输出清晰错误并终止构建。
3. 在应用包中创建 `Contents/Resources`。
4. 将图标复制为 `Contents/Resources/AppIcon.icns`。
5. 在 `Contents/Info.plist` 中加入 `CFBundleIconFile = AppIcon`。

加载应用图标不需要增加运行时代码。

## 失败处理

源图标缺失或为空时，构建必须在启动前失败，避免再次生成看似成功但图标空白的应用。

加入图标后，应用仍需支持通过 Xcode 和现有构建脚本运行。

## 验证标准

满足以下条件后才算完成：

- 构建后的应用包中存在 `AppIcon.icns`。
- `Info.plist` 包含 `CFBundleIconFile = AppIcon`。
- Finder 和显示简介面板能显示图标。
- 16 px 和 32 px 下仍能辨认窗口轮廓和两条状态线。
- `swift test` 继续通过。
- `./script/build_and_run.sh --verify` 能构建并启动应用。
- 菜单栏保持当前文字优先的显示方式，不发生变化。
