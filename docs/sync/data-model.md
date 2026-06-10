# Kite CloudKit 数据模型

## 当前本地事实

Kite 当前正式 Release 数据仍存储在：

```text
~/Library/Application Support/KiteNative/app-state.json
```

Debug 数据与正式数据隔离：

```text
~/Library/Application Support/KiteNative-Debug/app-state.json
```

CloudKit 迁移实验阶段允许把正式 Release JSON 复制到实验/同步库；不清理、不重置原始正式 Release 数据。

## 当前 AppState 来源

当前本地状态主要来自：

- `habits`
- `entries`
- `dailyOverrides`
- `hiddenHabits`
- `reminders`
- `uiPreferences`
- `focusSession`

第一版 CloudKit 同步只覆盖习惯和打卡强相关数据。

## v1 同步范围

第一版同步：

- 习惯模板：`HabitItem`
- 每日完成记录：`entries`
- 每日标题覆盖：`dailyOverrides`
- 每日隐藏记录：`hiddenHabits`

这些数据最能验证 Mac/iOS 双向编辑和自动同步。

## v1 暂不同步

第一版暂不同步：

- 提醒：`reminders`
- UI 偏好：`uiPreferences`
- 专注状态：`focusSession`

原因：

- 提醒涉及设备本地通知权限
- UI 偏好更适合每台设备独立保存
- 专注状态有明显设备现场属性

Mac 主 UI 进入同步库模式时，习惯相关字段来自 Core Data / CloudKit；`reminders`、`uiPreferences`、`focusSession` 仍从本机 JSON 读取并保存回本机 JSON，避免切到同步模式后丢失本机提醒、主题、置顶和专注状态。

## Core Data 实体方向

后续 Core Data 模型建议先拆为：

- `HabitEntity`
- `HabitEntryEntity`
- `DailyOverrideEntity`
- `HiddenHabitEntity`

每条记录至少保留：

- UUID
- createdAt
- updatedAt
- deletedAt

`HabitEntity.orderIndex` 使用 Core Data `integer64` 存储；Swift 读回时需兼容 `Int`、`Int64` 和 `NSNumber` 桥接。读取列表时按 `orderIndex`、`createdAt`、`id` 稳定排序，避免 Mac/iOS 在并列顺序下显示不一致。
Mac 和 iOS 在新增、仅今日改名、从选中日起改名时都会阻止同一天出现同名可见习惯；比较会去掉首尾空白和不可见控制字符后再做 Unicode 规范化，保持双端 UI 语义一致。
重复规则的自定义周几统一使用共享规范化：只保留 `1...7`，去重并排序；空自定义规则在保存时回退到当前选中日期的星期，读取已存储数据时回退为每天。
如果 CloudKit 合并后出现多条相同 `id` 的 `HabitEntity`，读取快照和全量状态时按 `updatedAt` / `createdAt` 保留最新记录，避免默认习惯或播种数据重复显示。
彻底删除习惯时，`HabitEntity` 使用 `deletedAt` 软删除并从快照/导出状态中过滤；同一 `id` 的重复记录里，删除记录优先于旧未删除记录，降低 CloudKit 延迟合并后的复活风险。
iOS 补齐默认习惯时如果发现相同 UUID 已有删除记录，不会重新创建该默认习惯；彻底删除表示用户明确不想再看到它。

`HabitEntryEntity`、`DailyOverrideEntity`、`HiddenHabitEntity` 需要包含 `dateKey`，用于表达某一天的记录。
如果 CloudKit 合并后同一天同一习惯出现多条 `HabitEntryEntity`，读取快照时按 `updatedAt` 取最新完成状态，避免旧的完成记录覆盖新的取消完成。
如果 CloudKit 合并后同一天同一习惯出现多条 `DailyOverrideEntity`，读取快照时按 `updatedAt` 取最新标题，避免重复 key 造成崩溃。
再次写入同一天同一习惯的完成状态、每日标题或隐藏记录时，Core Data store 会保留最新记录并删除本地已知的重复行。

## 迁移原则

第一步先在 Debug 数据中验证 JSON 到 Core Data 的映射。

当前已允许把正式 Release JSON 复制到实验 Core Data store，用于 CloudKit 播种和 iOS 互通验证。

正式 Release 数据迁移必须满足：

- 迁移前自动备份 `app-state.json`
- 迁移失败能继续使用旧本地数据
- 正式 App 默认数据源切到 Core Data/CloudKit 前，需要有明确版本策略

iOS 空状态里的“添加默认习惯”只补齐缺失的默认习惯 UUID，不使用 `replaceAll`，避免在 CloudKit-backed store 中覆盖已经同步的 Mac 数据。

Mac 主 UI 在同步库模式启动时只在内存中规范化显示数据，不自动 `replaceAll` 写回整个 Core Data store；整库写入只保留给显式“导入主同步库”等用户触发的播种动作。

`replaceAll(with:)` 只用于 Debug 实验库等需要清空重建的映射验证；清空旧 Core Data 记录时使用逐对象 `context.delete`，避免在 CloudKit-backed store 中使用 batch delete 绕开常规变更传播语义。
Mac 主同步库的正式 Release JSON 播种使用合并式导入：同 UUID habit、同日期 habit entry、同日期 daily override、同日期 hidden record 已存在时更新原对象，不存在时才插入，避免真实 CloudKit 验证中重复播种产生重复记录。
显式导入/播种会保留同步库里已有的 `deletedAt` 墓碑：旧 JSON 中同 UUID 的习惯会被跳过，并在导入后重新写回删除记录，避免再次导入正式 Release JSON 时复活用户已彻底删除的习惯。
如果源 JSON 自身包含重复 habit UUID，显式导入只接受第一条并跳过后续重复项；entries、daily overrides 和 hidden records 也只导入已接受 habit 的记录。
