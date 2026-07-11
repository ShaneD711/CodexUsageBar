# CodexUsageBar 未公证预览版发布设计

## 概述

CodexUsageBar 首个可下载版本将以 `v0.1.0 Unnotarized Preview` 的形式通过 GitHub Releases 发布。该版本面向能够理解 macOS 首次打开时需要手动放行的早期技术用户。

该版本不通过 Mac App Store 发布，不要求加入 Apple Developer Program，不使用 Developer ID 证书，也不提交 Apple 公证。

## 目标

- 提供可复现的 Apple Silicon Release 构建，让用户不安装 Xcode 也能下载应用。
- 将有效的 macOS 应用包打包为 ZIP。
- 对完整应用包进行临时签名以封装内容，但不宣称获得 Apple 信任或公证。
- 随安装包发布 SHA-256 校验值。
- 在中英文文档中说明安装、Gatekeeper 手动放行、卸载、隐私和支持边界。
- 加入 MIT License，使仓库具备明确的开源许可证。

## 不在范围内

- Mac App Store 发布。
- Developer ID 签名或 Apple 公证。
- Intel Mac 支持。
- DMG 或 PKG 安装器。
- GitHub Actions 自动发布。
- 自动更新。

## 支持环境

- 版本：`0.1.0`
- 产品标记：`Unnotarized Preview`
- 系统：macOS 14 或更高版本
- 架构：仅 Apple Silicon（`arm64`）
- 前置条件：同一台 Mac 已安装并登录 ChatGPT/Codex
- 许可证：MIT

## 发布产物

发布打包脚本会在被 Git 忽略的 `dist/release/` 目录生成：

```text
CodexUsageBar-v0.1.0-macos-arm64.zip
CodexUsageBar-v0.1.0-macos-arm64.zip.sha256
```

ZIP 中包含 `CodexUsageBar.app`，校验文件中包含 SHA-256 摘要和安装包文件名。未压缩的应用会在系统临时目录中组装并签名，避免 Finder 或文件提供器元数据在打包前修改应用包。

## 打包流程

新增 `script/package_release.sh`，版本号通过参数传入：

```bash
./script/package_release.sh 0.1.0
```

脚本依次执行：

1. 验证版本号符合数字形式的 `major.minor.patch`。
2. 运行 Swift 测试。
3. 以 Release 模式为 `arm64` 编译可执行文件。
4. 在系统临时目录中创建干净的 `CodexUsageBar.app`。
5. 将 Release 可执行文件和仓库中的图标复制到应用包。
6. 生成 `Info.plist`，写入 Bundle ID、应用名、最低系统版本、仅菜单栏行为、版本号和构建号。
7. 对完整应用包进行临时签名。
8. 验证应用包签名和可执行文件架构。
9. 在保留应用结构和可执行权限的同时排除不必要的扩展属性并生成 ZIP。
10. 解压 ZIP 并再次验证其中应用的签名。
11. 生成 SHA-256 校验文件。

现有 `script/build_and_run.sh` 继续只负责开发环境的构建和启动，不承担正式打包职责。

## 签名与信任模型

预览版只使用临时签名。它可以封装当前应用包内容，但不能向 Apple 证明发布者身份，也不能让 Gatekeeper 将其识别为“已识别开发者”应用。

文档和 Release Notes 必须明确说明：

- 应用没有使用 Apple Developer ID 签名。
- 应用没有经过 Apple 公证。
- macOS 很可能阻止首次启动。
- 用户应先自行判断是否信任 GitHub 仓库和校验值，再手动放行。

任何文档都不能把预览版描述为经过 Apple 签名、验证、信任或批准。

## 安装流程

面向用户的安装步骤为：

1. 从 GitHub Release 下载 ZIP 和校验文件。
2. 根据需要验证 SHA-256。
3. 解压得到 `CodexUsageBar.app`。
4. 将应用移动到 `/Applications`。
5. 尝试打开一次。
6. 打开 `系统设置 > 隐私与安全性`，找到 CodexUsageBar 并点击“仍要打开”。
7. 再次确认警告，并在系统要求时输入 Mac 登录密码。
8. 在 macOS 顶部菜单栏找到 CodexUsageBar。

文档需要说明：公司或学校管理的 Mac 可能禁止手动放行；下载新版本后，也可能需要重新批准。

## 文档变更

- 新增 MIT `LICENSE` 文件。
- 在 `README.md` 和 `README.zh-CN.md` 中加入下载与安装章节。
- 加入 `shasum -a 256 -c` 校验说明。
- 加入卸载说明，移除 `CodexUsageBar.app`，并可通过 `defaults delete com.shaned.CodexUsageBar` 清除其 `UserDefaults` 缓存。
- 明显标注“未公证预览版”。
- 将当前更新日志整理到带日期的 `0.1.0` 版本章节。
- 为仓库维护者准备手动创建 GitHub Release 时使用的标题和说明。

## 验证要求

上传前必须通过：

- `swift test`
- Release 构建成功
- `file` 或 `lipo` 确认为 `arm64`
- `plutil -lint` 验证 `Info.plist`
- `codesign --verify --deep --strict` 验证临时签名成功
- 从 ZIP 解压出的应用也能通过严格签名验证
- ZIP 不包含 `__MACOSX` 或 `._` AppleDouble 元数据条目
- ZIP 解压后只得到一个可用的 `CodexUsageBar.app`
- SHA-256 校验文件与 ZIP 一致
- 打包后的应用能在开发 Mac 上启动并读取 Codex 用量

由于该版本没有 Developer ID 签名和 Apple 公证，因此通过 Gatekeeper 自动信任不属于成功标准。

## 手动创建 GitHub Release

实现完成并提交、推送后，由仓库所有者：

1. 从验证通过的发布提交创建 `v0.1.0` 标签。
2. 创建名为 `CodexUsageBar v0.1.0 - Unnotarized Preview` 的 GitHub Release。
3. 上传 ZIP 和 SHA-256 文件。
4. 粘贴准备好的 Release Notes。
5. 将该版本标记为 Pre-release。

构建产物继续由 Git 忽略；Git 仓库只提交源码、脚本、许可证和文档。
