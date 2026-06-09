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

CloudKit 迁移实验阶段不迁移、不清理、不重置正式 Release 数据。

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

`HabitEntryEntity`、`DailyOverrideEntity`、`HiddenHabitEntity` 需要包含 `dateKey`，用于表达某一天的记录。

## 迁移原则

第一步只在 Debug 数据中验证 JSON 到 Core Data 的映射。

正式 Release 数据迁移必须满足：

- 迁移前自动备份 `app-state.json`
- 迁移失败能继续使用旧本地数据
- 迁移动作只在用户明确要求或正式版本策略确认后执行
