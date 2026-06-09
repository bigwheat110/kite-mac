# Kite Core Data 实验说明

## 目标

这份文档记录 CloudKit 前置实验：先把现有 JSON 状态映射到 Core Data 实体，但不替换当前 UI 数据源。

当前实验只验证模型拆分是否可行。

## 实验入口

Debug 构建中新增：

```swift
HabitCoreDataExperiment.importDebugState()
HabitCoreDataExperiment.importReleaseStateReadOnly()
HabitCoreDataExperiment.clearExperimentStore()
```

这些入口只存在于 `#if DEBUG`。

设置页 Debug 构建中也新增了 `Core Data 实验` 区块：

- `导入 Debug`
- `只读正式数据`
- `清理实验库`

该区块不会出现在 Release 构建中。

## 数据来源

`importDebugState()` 读取：

```text
~/Library/Application Support/KiteNative-Debug/app-state.json
```

`importReleaseStateReadOnly()` 读取：

```text
~/Library/Application Support/KiteNative/app-state.json
```

Release JSON 只读，不写回、不迁移、不删除。

## 实验 Store

Core Data 实验写入独立 store：

```text
~/Library/Application Support/KiteNative-CoreDataExperiment/kite-core-data-experiment.sqlite
```

这个 store 不参与当前 UI 读写，也不参与 CloudKit 同步。

## 当前实体

实验模型包含：

- `HabitEntity`
- `HabitEntryEntity`
- `DailyOverrideEntity`
- `HiddenHabitEntity`

暂不包含：

- 提醒
- UI 偏好
- 专注状态

## 下一步

1. 用 Debug 数据运行映射检查。
2. 确认习惯、打卡、每日改名、每日隐藏数量正确。
3. 观察设置页展示的映射统计。
4. 模型稳定后再考虑 `NSPersistentCloudKitContainer`。
