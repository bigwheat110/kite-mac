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
- 用共享快照接口对比 JSON 与 Core Data 的当天显示结果
- 当前实验说明见 `docs/sync/core-data-experiment.md`

边界：

- 不触碰 Release 数据
- 不打开 CloudKit 同步
- 不替换现有 UI 读写路径

当前状态：

- 已有 Debug-only 导入、预览、清理入口
- 已有 `HabitSyncStore` / `HabitDaySnapshot`
- 已有 `HabitSnapshotBuilder` 统一当天习惯可见性、标题覆盖和完成状态
- 已有 `HabitCoreDataStack` 作为 Mac / CloudKit / iOS 共享 Core Data 模型定义
- 已有 `HabitCoreDataStore` 作为共享 Core Data 读写 API
- `HabitCoreDataStore` 已覆盖新增、打卡、每日改名、模板改名、每日隐藏、从选中日后删除等 v1 写操作
- 已有 JSON/Core Data 对比入口
- Debug 面板已有 `写入演练`，可在独立实验库中验证 Core Data 单步写操作

## 阶段 3：Mac 本地持久化切换

目标：

- Mac Debug 版本支持通过 `HabitCoreDataStore` 读写
- 将现有 UI 的新增、编辑、完成、隐藏等操作在 Debug 模式下接到 Core Data 试运行路径
- 保留旧 JSON 备份和回退空间
- 验证新增、编辑、完成、隐藏功能正常

当前状态：

- 已新增 Core Data 试运行模式，默认关闭
- 试运行模式下，Mac UI 会从独立实验库读取习惯数据
- 试运行模式下，新增、打卡、每日改名、模板改名、隐藏、从选中日后删除、重复规则、排序会写入 `HabitCoreDataStore`
- 试运行模式不会保存到当前 JSON 数据源，关闭后回到 JSON

边界：

- 只在 Debug 中存在
- 不迁移 Release 数据
- 不替换 Release JSON 数据源
- 暂不接提醒、UI 偏好、专注状态

## 阶段 4：开启 CloudKit

目标：

- 配置 iCloud capability
- 配置 CloudKit container
- 使用 `NSPersistentCloudKitContainer`
- 验证同一 Apple ID 下 Mac 设备间同步

当前状态：

- 已新增 macOS entitlement: `NativeMac/KiteNative/KiteNative.entitlements`
- 已新增 iOS entitlement: `NativeMac/KiteIOS/KiteIOS.entitlements`
- 预留 CloudKit container: `iCloud.cn.kitlib.kite`
- 已新增 `HabitCoreDataStack.makeCloudKitContainer(storeURL:)`
- 已新增 `HabitSyncStoreFactory` / `HabitSyncStoreMode`，默认仍创建本地 Core Data store
- 已新增 CloudKit 试运行启动参数：`--kite-sync-cloudkit`

边界：

- 尚未选择 Apple Developer Team
- 尚未在真机/模拟器验证 iCloud 登录状态
- 默认不带启动参数时，Mac/iOS 仍使用本地 Core Data store
- 只有带 `--kite-sync-cloudkit` 时才尝试 CloudKit-backed store
- CloudKit 试运行 store 使用独立目录，目录名追加 `-CloudKit`
- Mac Debug Core Data 实验面板跟随同一个启动参数和 store mode
- Mac Debug Core Data 实验面板已提供只读 iCloud 账号状态检查
- Mac Debug Core Data 实验面板已提供 CloudKit 同步事件诊断
- 尚未进行多设备同步验证

## 阶段 5：iOS 只读版

目标：

- 新增 SwiftUI iOS 目标
- 复用 `Shared` 下的模型、日期工具和快照规则
- 读取同一个 Core Data / CloudKit 模型
- 先展示习惯和打卡记录

当前状态：

- 已新增 `KiteIOS` target
- 已新增 iOS SwiftUI 页面
- 当前页面复用 `HabitModels`、`HabitSyncModels`、`HabitCoreDataStack` 和 `HabitCoreDataStore`
- 当前 iOS 页面已通过 `HabitCoreDataStore` 读取 iOS 本地 Core Data store
- 只读阶段已越过，iOS 已开始支持本地编辑
- 当前 iOS 页面尚未接 CloudKit，因此不会自动读取 Mac 正式 JSON 数据

## 阶段 6：iOS 双向编辑

目标：

- iOS 支持新增、编辑、完成、隐藏
- 验证 Mac/iOS 双向同步
- 观察是否需要额外冲突提示

当前状态：

- iOS 已支持日期前后切换和回到今天
- iOS 已支持新增习惯和仅选中日新增
- iOS 已支持点击打卡/取消打卡
- iOS 已支持长按菜单：仅选中日改名、从选中日起改名、仅选中日隐藏、从选中日起删除
- iOS 已支持重复规则：每天、工作日、周末、自定义周几
- iOS 已支持拖动排序
- iOS 空状态已支持手动添加默认习惯
- iOS 已新增同步状态页，显示本地/CloudKit 模式、iCloud 账号状态和最近刷新时间
- iOS 同步状态页已显示模式说明、实际 SQLite 路径和 CloudKit 试运行启动参数提示
- iOS 同步状态页已新增 CloudKit 同步事件诊断，用于观察系统导入/导出/失败事件
- iOS 在 CloudKit 导入完成事件后会自动刷新当前日期快照
- 当前写入的是 iOS 本地 Core Data store
- 尚未验证 Mac/iOS CloudKit 双向同步
- Mac/iOS 都已接入 iCloud 账号状态检查和 CloudKit 同步事件诊断
- Mac/iOS 在 CloudKit 导入完成事件后都会重读本地 Core Data 数据
