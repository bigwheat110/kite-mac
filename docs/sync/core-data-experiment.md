# Kite Core Data 实验说明

## 目标

这份文档记录 CloudKit 前置实验：先把现有 JSON 状态映射到 Core Data 实体，但不替换当前 UI 数据源。

当前实验只验证模型拆分是否可行。

## 实验入口

Debug 构建中新增：

```swift
HabitCoreDataExperiment.importDebugState()
HabitCoreDataExperiment.importReleaseStateReadOnly()
HabitCoreDataExperiment.runWriteExercise(on:)
HabitCoreDataExperiment.clearExperimentStore()
```

这些入口只存在于 `#if DEBUG`。

设置页 Debug 构建中也新增了 `Core Data 实验` 区块：

- `导入 Debug`
- `只读正式数据`
- `预览今天`
- `对比今天`
- `写入演练`
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

默认不带启动参数时，这个 store 不参与当前 UI 读写，也不参与 CloudKit 同步。

实验 store 通过 `HabitCoreDataStack.makeLocalContainer(storeURL:)` 创建。未来 Mac Debug 本地 Core Data 试运行、CloudKit container 和 iOS 目标都应复用同一套模型定义。

如果启动参数包含 `--kite-sync-cloudkit`，Debug 实验面板会跟随切到 CloudKit-backed 试运行 store：

```text
~/Library/Application Support/KiteNative-CoreDataExperiment-CloudKit/kite-core-data-experiment.sqlite
```

这样导入、预览、对比、写入演练和 Mac UI 试运行会使用同一个 store mode。

Debug 实验面板会显示：

- 当前模式：`本地 Core Data` 或 `iCloud / CloudKit`
- 当前模式说明
- 实际 SQLite store 路径
- 本地模式下的 CloudKit 试运行启动参数提示

后续验证截图时，应先确认面板里的当前模式和 store 路径，避免把本地实验结果误认为 iCloud 同步结果。

Core Data 导入和查询逻辑已抽到 `NativeMac/Shared/HabitCoreDataStore.swift`：

- `addHabit(title:startDate:todayOnly:id:)`
- `setDone(_:habitID:on:)`
- `toggleDone(habitID:on:)`
- `renameHabitForDay(habitID:title:on:)`
- `renameHabitFromDate(habitID:title:from:)`
- `hideHabitForDay(habitID:on:)`
- `endHabitFromDate(habitID:from:)`
- `deleteHabit(habitID:)`
- `reorderHabits(orderedIDs:)`
- `replaceAll(with:)`
- `daySnapshot(for:)`
- `daySummary(for:)`
- `clearStoreFile()`

Debug 实验入口只负责选择 JSON 来源和展示结果，不再直接维护 Core Data 写入/读取细节。当前这些写操作是共享数据层能力，尚未替换正式 UI 的 JSON 写入路径。

`clearStoreFile()` 会删除实验 SQLite 主文件及旁文件：

- `.sqlite`
- `.sqlite-wal`
- `.sqlite-shm`

`写入演练` 会在独立实验 store 里执行一组 Core Data 写操作：

- 新增一个测试习惯
- 设置当天完成
- 写入每日改名
- 写入从当天起的模板改名
- 写入当天隐藏
- 写入从当天起的截止日期

演练会让实验 store 与当前 JSON 状态不再完全一致。需要重新验证 JSON/Core Data 映射时，先点 `清理实验库`，再重新 `导入 Debug` 或 `只读正式数据`。

## 当前实体

Core Data 模型定义已抽到 `NativeMac/Shared/HabitCoreDataStack.swift`。

当前共享模型包含：

- `HabitEntity`
- `HabitEntryEntity`
- `DailyOverrideEntity`
- `HiddenHabitEntity`

暂不包含：

- 提醒
- UI 偏好
- 专注状态

## CloudKit 模型约束

`HabitCoreDataStack` 里的非可选属性已设置默认值，降低后续切换 `NSPersistentCloudKitContainer` 时的模型兼容风险。

后续新增 Core Data 字段时需要遵守：

- 优先使用可选属性，或给非可选属性设置默认值
- 不在第一版使用关系建模，继续用 `habitID` 等稳定 ID 关联
- 不把提醒、UI 偏好、专注状态混入 v1 同步模型
- CloudKit 真正打开前，仍先在本地 Core Data store 验证读写

## 共享查询雏形

当前已新增 `HabitSyncStore` 和 `HabitDaySnapshot`，用于表达“某一天应该显示什么”。

`HabitSnapshotBuilder` 负责从 `AppState` 生成当天快照，统一处理：

- 当天可见习惯
- 每日标题覆盖
- 历史标题
- 每日完成状态
- 每日隐藏
- 重复规则与开始/结束日期

Debug 实验层提供 `HabitCoreDataExperimentStore`，可以从实验 Core Data store 读取当天快照。

同时提供 `HabitJSONSnapshotStore` 和 `HabitSnapshotComparator`，用于把当前 JSON 状态与实验 Core Data store 的当天快照做对比。`对比今天` 会检查可见习惯数量、完成数量，以及每一项的顺序、标题和完成状态。

这一步是未来 Mac / iOS 共用数据层的前置工作，但当前 UI 仍未切换到 Core Data，正式 Release 数据仍使用 JSON。

## 下一步

1. 用 Debug 数据运行映射检查。
2. 确认习惯、打卡、每日改名、每日隐藏数量正确。
3. 点击 `预览今天`，确认 Core Data 反查出的可见习惯、完成数、隐藏数和页面预期一致。
4. 点击 `对比今天`，确认 JSON 与 Core Data 当天快照匹配。
5. 点击 `写入演练`，验证 Core Data 单步写操作能落库并被当天快照读取。
6. 查看 Debug 面板的当前模式和 store 路径，确认仍在本地实验库。
7. 模型稳定后，带 `--kite-sync-cloudkit` 启动，再确认面板显示 `iCloud / CloudKit` 和 `KiteNative-CoreDataExperiment-CloudKit` 路径。
8. 进入 CloudKit-backed store 后再做 Mac/iOS 同 Apple ID 同步验证。
