# Kite CloudKit 同步进展

## 当前状态

- 当前仓库是 `kite-mac`。
- 当前应用是原生 macOS 实现。
- 当前正式数据仍是本地 JSON。
- 当前同步主线已调整为 iCloud / CloudKit。
- 自建 FastAPI/PostgreSQL 后端不再作为第一阶段主线。

## 已确认决策

- 第一版只面向 Apple 生态：macOS + iOS。
- 第一版用户不需要提供服务器。
- 同步主线使用 Core Data + CloudKit。
- 优先使用用户私有 iCloud 数据库。
- 不采用 OneDrive / Dropbox / iCloud Drive 文件夹同步作为主线。
- v1 同步范围仍为习惯、每日完成记录、每日改名、每日隐藏。
- 暂不同步提醒、UI 偏好、专注状态。

## 当前推进判断

Kite 当前更适合先做 Apple 原生同步，而不是自建后端。

主要原因：

- 使用门槛低
- 用户不需要部署
- Mac/iOS 原生体验更自然
- 第一版可更快验证产品价值

## 风险

- CloudKit 只适合 Apple 生态，后续跨平台需要重新评估后端方案。
- Core Data 迁移需要谨慎，不能影响正式 Release 数据。
- CloudKit 同步时机由系统管理，不适合做强实时协作。
- 提醒和专注状态跨设备语义复杂，暂不进入第一版同步范围。

## 下一步

1. 确认 Apple Developer 账号和 iCloud capability 可用。
2. 设计 Core Data 模型。
3. 先在 Debug 数据中验证 JSON 到 Core Data 的映射。
4. 再考虑开启 CloudKit container。
