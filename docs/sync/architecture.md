# Kite iCloud 同步架构

## 目标

这份文档只服务 Kite 第一版 Apple 生态多端同步落地，不做完整跨平台 SaaS 架构设计。

当前目标：

- Mac 和 iPhone 使用同一份习惯数据
- 用户不需要提供服务器
- 数据使用用户自己的 Apple ID / iCloud 承载
- 先跑通个人多端同步，不做多人共享

## 当前主线

第一版同步主线改为：

- Core Data
- CloudKit
- `NSPersistentCloudKitContainer`
- 用户私有 iCloud 数据库

当前预留 CloudKit container：

- `iCloud.cn.kitlib.kite`

该 container 需要在 Apple Developer 账号和 Xcode Signing & Capabilities 中确认后才能用于真实同步。

自建 `FastAPI + PostgreSQL` 后端不再作为当前主线，只保留为未来跨平台或 SaaS 化时的备选。

## 为什么不用自建服务器

自建服务器的优点是灵活，后续可以做 Web、团队、后台管理和跨平台。

但对 Kite 当前阶段来说，它会带来明显门槛：

- 用户需要信任或配置服务器
- 需要处理部署、运维、备份和 HTTPS
- App 首版会被后端复杂度拖慢

Kite 第一版先面向 Apple 生态，使用 iCloud 更符合普通用户预期。

## 为什么不用 OneDrive / iCloud Drive 文件同步

Obsidian 适合文件夹同步，是因为它的核心数据天然是一组 Markdown 文件。

Kite 当前是结构化 App 状态，包含习惯、打卡、每日覆盖和隐藏记录。直接同步一个 JSON 文件或文件夹会有几个问题：

- Mac/iOS 同时编辑时容易产生文件冲突
- 很难做字段级合并
- iOS 沙盒和文件选择会增加使用成本
- 后续结构化查询、软删除和冲突提示会变别扭

因此第一版不采用 OneDrive、Dropbox 或 iCloud Drive 文件夹同步作为主线。

## 当前边界

第一版只做：

- 个人数据同步
- macOS + iOS
- 用户私有 iCloud 数据库
- 习惯和打卡相关数据

第一版不做：

- Windows / Android / Web
- 团队和共享
- 自建服务器
- 实时协同
- 复杂冲突 UI

## 工程准备状态

当前工程已准备：

- macOS entitlement: `NativeMac/KiteNative/KiteNative.entitlements`
- iOS entitlement: `NativeMac/KiteIOS/KiteIOS.entitlements`
- `HabitCoreDataStack.makeLocalContainer(storeURL:)`
- `HabitCoreDataStack.makeCloudKitContainer(storeURL:)`
- `HabitSyncStoreFactory`，用于在本地 Core Data 和 CloudKit-backed Core Data 之间切换
- 启动参数 `--kite-sync-cloudkit`，用于手动进入 CloudKit-backed 试运行模式
- Mac Debug 实验面板会显示当前 store mode、模式说明和实际 SQLite 路径
- Debug 构建可在 Mac Debug 面板和 iOS 同步页设置“下次启动”同步模式
- Mac Debug 面板和 iOS 同步页会显示实际 Bundle ID 和 CloudKit container，便于核对配置

当前尚未完成：

- Apple Developer Team 选择
- CloudKit container 后台确认
- Mac/iOS 实际切换到 CloudKit-backed store
- 多设备同步验证

当前默认仍使用本地 Core Data store；CloudKit-backed store 只是代码入口已准备好。

同步模式解析优先级：

1. 启动参数 `--kite-sync-cloudkit`
2. Debug 偏好里的下次启动模式
3. 默认本地 Core Data

同步模式会在进程启动时冻结为 `HabitSyncStoreMode.current`。Debug 偏好只在下次 App 启动时生效，当前运行中的 store 不会被热切换。

CloudKit 试运行使用独立 store 目录：

- 本地模式：调用方传入的原目录名
- CloudKit 模式：原目录名追加 `-CloudKit`

这样可以避免第一次 CloudKit 试运行时混用本地实验库。

首次真实同步验证按 `docs/sync/cloudkit-verification.md` 执行。
