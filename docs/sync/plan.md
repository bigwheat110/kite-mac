# Kite CloudKit 同步阶段计划

## 阶段 1：文档重定向

目标：

- 将同步主线从自建后端改为 iCloud / CloudKit
- 删除后端原型方向文档
- 明确 Apple 生态优先

边界：

- 不实现 CloudKit 代码
- 不迁移正式数据
- 不运行测试和构建

## 阶段 2：Core Data 模型实验

目标：

- 新增 Core Data 模型草案
- 将 v1 同步范围拆成实体
- 在 Debug 数据中验证 `AppState` 到 Core Data 的映射
- 当前实验说明见 `docs/sync/core-data-experiment.md`

边界：

- 不触碰 Release 数据
- 不打开 CloudKit 同步
- 不替换现有 UI 读写路径

## 阶段 3：Mac 本地持久化切换

目标：

- Mac Debug 版本支持从 Core Data 读取和写入
- 保留旧 JSON 备份和回退空间
- 验证新增、编辑、完成、隐藏功能正常

## 阶段 4：开启 CloudKit

目标：

- 配置 iCloud capability
- 配置 CloudKit container
- 使用 `NSPersistentCloudKitContainer`
- 验证同一 Apple ID 下 Mac 设备间同步

## 阶段 5：iOS 只读版

目标：

- 新增 SwiftUI iOS 目标
- 读取同一个 Core Data / CloudKit 模型
- 先展示习惯和打卡记录

## 阶段 6：iOS 双向编辑

目标：

- iOS 支持新增、编辑、完成、隐藏
- 验证 Mac/iOS 双向同步
- 观察是否需要额外冲突提示
