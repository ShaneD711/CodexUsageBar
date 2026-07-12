# CodexUsageBar GitHub Actions CI 设计

[English](2026-07-12-github-actions-ci-design.md) | [简体中文](2026-07-12-github-actions-ci-design.zh-CN.md)

日期：2026-07-12

## 目标

为每次推送到 `main` 和每个 Pull Request 提供独立于开发者电脑的自动检查记录，防止无法编译、测试失败或脚本语法错误的代码进入主分支。

## 工作流

单一 `.github/workflows/ci.yml` 工作流运行于稳定的 Apple Silicon `macos-15` GitHub 托管 Runner，并依次执行：

1. 使用官方 `actions/checkout` 获取源码。
2. 输出 Swift 和 Xcode 版本，方便排查 Runner 变化。
3. 使用 `bash -n` 检查开发与发布脚本语法。
4. 使用 `swift test` 运行全部单元测试。
5. 使用 `swift build --configuration release --arch arm64` 验证发布配置可编译。

工作流支持手动触发，并使用并发取消策略：同一分支出现新提交时，取消旧的未完成运行。

## 权限与边界

- 只授予 `contents: read` 权限。
- 不使用仓库 Secret。
- 不登录 Codex，不读取真实账号用量。
- 不签名、不打包、不上传安装包、不创建 Tag 或 GitHub Release。
- 不运行菜单栏 UI 自动化测试。

## 成功标准

- Push 和 Pull Request 页面显示 CI 检查状态。
- 任一测试、脚本检查或 Release 编译失败时，工作流返回失败。
- 本地 `swift test` 和 CI 使用同一套测试源码。
- README 能显示当前 CI 状态。
