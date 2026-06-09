# Kite CloudKit 同步设计

## 同步策略

第一版采用 Apple 原生同步能力：

- Core Data 作为本地持久化
- CloudKit 作为云端同步层
- `NSPersistentCloudKitContainer` 负责本地和 iCloud 私有库同步

客户端仍然是本地优先：App 打开时先读本地 Core Data，系统后台再同步 iCloud 变更。

## 数据库范围

使用用户自己的私有 iCloud 数据库。

第一版不使用公共数据库，也不做共享数据库。

这意味着：

- 用户不需要注册 Kite 后端账号
- 用户不需要提供服务器
- 数据跟随 Apple ID
- 多端同步依赖 iCloud 登录和网络状态

## 冲突处理

第一版先依赖 Core Data + CloudKit 的系统合并能力。

Kite 自己需要在数据模型上做好准备：

- 所有同步实体使用稳定 UUID
- 记录 `updatedAt`
- 删除使用 `deletedAt` 软删除
- 关键操作避免直接覆盖整份状态

后续如果发现同一字段多端编辑冲突明显，再增加专门的冲突提示 UI。

## 和文件同步的区别

iCloud Drive 文件同步适合“用户管理文件”的应用。

Kite 更适合 CloudKit，因为：

- 数据是结构化实体，不是一组用户手动编辑的文件
- 需要长期支持增量合并
- 需要避免整份 JSON 被不同设备互相覆盖
- 后续 iOS 双向编辑会更自然

## 当前不做

第一版不做：

- 自建 API
- 用户账号系统
- WebSocket
- CRDT
- 多人共享
- 跨平台同步
