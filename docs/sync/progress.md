# Kite CloudKit 同步进展

## 当前状态

- 当前仓库是 `kite-mac`。
- 当前应用是原生 macOS 实现。
- 当前正式数据仍是本地 JSON。
- 当前同步主线已调整为 iCloud / CloudKit。
- 自建 FastAPI/PostgreSQL 后端不再作为第一阶段主线。
- 已新增 Debug-only Core Data 实验入口。
- 已新增共享快照接口 `HabitSyncStore`、`HabitDaySnapshot`。
- 已新增 `HabitSnapshotBuilder`，用于统一 Mac 当前 UI、JSON 快照和未来 iOS 的当天习惯显示规则。
- 已新增 `HabitCoreDataStack`，作为未来 Mac / CloudKit / iOS 复用的 Core Data 模型和本地 container 工厂。
- 已新增 `HabitCoreDataStore`，作为未来 Mac / CloudKit / iOS 复用的 Core Data 读写 API。
- `HabitCoreDataStore` 已覆盖新增、打卡、每日改名、模板改名、每日隐藏、从选中日后删除等 v1 写操作。
- 已新增 JSON/Core Data 当天快照对比能力，用于验证迁移映射是否与当前 UI 语义一致。
- Debug 面板已新增 `写入演练`，用于在独立实验库中验证 Core Data 单步写操作。
- Debug 面板已新增 `同步标记`，用于写入可见的 Mac -> iOS CloudKit 验证习惯。
- 已新增 `KiteIOS` target 和 iOS SwiftUI 页面。
- iOS 页面当前复用 `HabitModels`、`HabitSyncModels`、`HabitCoreDataStack` 和 `HabitCoreDataStore`。
- iOS 页面已从默认样例状态切到 `HabitCoreDataStore` 数据源，默认读取 iOS 本地 Core Data store。
- iOS 页面已支持日期前后切换和回到今天。
- iOS 页面已支持本地 Core Data 新增、仅选中日新增、打卡、仅选中日改名、从选中日起改名、仅选中日隐藏、从选中日起删除。
- iOS 页面已支持重复规则：每天、工作日、周末、自定义周几。
- iOS 页面已支持通过系统编辑模式拖动排序，排序写入 Core Data。
- iOS 空状态已支持手动添加默认习惯，写入 iOS 本地 Core Data store。
- iOS 同步页已新增 `写入同步标记`，用于写入可见的 iOS -> Mac CloudKit 验证习惯。
- iOS 页面已新增同步状态入口，显示当前 store 模式、iCloud 账号状态、最近刷新时间，并提供手动刷新。
- iOS 同步状态页已显示模式说明、实际 SQLite 路径和 CloudKit 试运行启动参数提示。
- iOS 同步状态页已新增 CloudKit 同步事件诊断；CloudKit-backed 模式下会显示最近一次系统导入/导出/失败事件。
- iOS iCloud 账号检查失败时会显示具体错误信息。
- iOS 在 CloudKit 导入完成事件后会自动重读当前日期快照。
- iOS 同步状态页已显示实际 Bundle ID 和 CloudKit container，便于核对签名配置。
- iOS 页面尚未接 CloudKit，因此当前不会自动看到 Mac 正式 JSON 数据。
- Mac Debug 已新增 Core Data 试运行模式，默认关闭。
- Core Data 试运行模式打开后，Mac UI 的新增、打卡、每日改名、模板改名、隐藏、从选中日后删除、重复规则、排序会读写独立实验库。
- Core Data 试运行模式不会保存到当前 JSON 数据源，关闭后回到 JSON。
- 已新增 macOS/iOS CloudKit entitlements，占位 container 为 `iCloud.cn.kitlib.kite`。
- `HabitCoreDataStack` 已新增 `makeCloudKitContainer(storeURL:)`，用于后续切换 `NSPersistentCloudKitContainer`。
- 已新增 `HabitSyncStoreFactory` 和 `HabitSyncStoreMode`，统一创建本地 / CloudKit-backed Core Data store。
- 已新增 `HabitCloudKitSyncMonitor`，用于监听 `NSPersistentCloudKitContainer` 的同步事件通知。
- 已新增 CloudKit 试运行启动参数 `--kite-sync-cloudkit`；默认不带参数时仍使用本地 Core Data。
- 已新增 Debug 同步模式偏好；Mac Debug 面板和 iOS 同步页可设置下次启动使用本地 Core Data 或 CloudKit-backed store。
- 同步模式解析优先级：启动参数 `--kite-sync-cloudkit` 优先，其次 Debug 偏好，最后默认本地 Core Data。
- 同步模式在进程启动时冻结为 `HabitSyncStoreMode.current`，修改 Debug 偏好不会热切换当前运行中的 store。
- CloudKit 试运行模式使用独立 store 目录，目录名在本地模式基础上追加 `-CloudKit`，避免混用本地实验库。
- Mac Debug Core Data 实验面板已跟随 `--kite-sync-cloudkit`，导入、预览、对比、写入演练和 Mac UI 试运行使用同一个 store mode。
- Mac Debug Core Data 实验面板已显示当前 store mode、模式说明和实际 SQLite 路径，方便区分本地实验库和 CloudKit 实验库。
- Mac Debug Core Data 实验面板已显示实际 Bundle ID 和 CloudKit container，便于核对签名配置。
- Mac Debug Core Data 实验面板已新增只读 iCloud 账号状态检查。
- Mac Debug Core Data 实验面板已新增 CloudKit 同步事件诊断；CloudKit-backed 模式下会显示最近一次系统导入/导出/失败事件。
- Mac Debug Core Data 试运行模式在 CloudKit 导入完成事件后会自动重读独立实验库。
- Core Data 模型里的非可选属性已补默认值，降低后续切换 CloudKit-backed store 的模型兼容风险。
- 当前尚未选择 Apple Developer Team，尚未验证真实 iCloud 同步。
- 已新增首次真实同步验证清单：`docs/sync/cloudkit-verification.md`。
- iCloud 账号状态检查只是只读诊断，不代表 CloudKit 同步已经可用。

## 已确认决策

- 第一版只面向 Apple 生态：macOS + iOS。
- 第一版用户不需要提供服务器。
- 同步主线使用 Core Data + CloudKit。
- 优先使用用户私有 iCloud 数据库。
- 不采用 OneDrive / Dropbox / iCloud Drive 文件夹同步作为主线。
- v1 同步范围仍为习惯、每日完成记录、每日改名、每日隐藏。
- 暂不同步提醒、UI 偏好、专注状态。
- iOS 重复规则已覆盖 v1 同步所需语义。

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

1. 用 Debug 面板继续验证 `导入`、`预览今天`、`对比今天`。
2. 用 Debug 面板运行 `写入演练`，确认 Core Data 本地写入和当天快照读取正常。
3. 手动体验 Core Data 试运行模式，确认 Mac UI 常用操作在实验库内可用。
4. 确认 Apple Developer Team，并在 Apple Developer / Xcode 中确认 `iCloud.cn.kitlib.kite` container。
5. 在 Team/container 确认后，用 `--kite-sync-cloudkit` 启动 Mac Debug 和 iOS，验证同一 Apple ID 下同步。
