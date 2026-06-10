# Kite CloudKit 验证清单

这份清单用于第一次验证 Mac / iOS 是否能通过同一个 iCloud 私有库同步。

## 前置配置

- 签名和 Apple Developer 后台准备见 `docs/sync/signing-checklist.md`。
- 构建前可先运行静态配置检查：

```bash
bash scripts/verify-cloudkit-config.sh
```

- Xcode Signing Team 已选择同一个 Apple Developer Team。
- Mac target bundle id: `cn.kitlib.kitemac`。
- iOS target bundle id: `cn.kitlib.kiteios`。
- Xcode shared schemes 包含 `KiteNative` 和 `KiteIOS`。
- Mac entitlement: `NativeMac/KiteNative/KiteNative.entitlements`。
- iOS entitlement: `NativeMac/KiteIOS/KiteIOS.entitlements`。
- iOS entitlement 包含 `aps-environment`，Debug 为 `development`，Release 为 `production`。
- iOS Info.plist: `NativeMac/KiteIOS/Info.plist`，包含 `UIBackgroundModes` / `remote-notification`。
- 两个 entitlement 都包含同一个 container:

```text
iCloud.cn.kitlib.kite
```

- Apple Developer / Xcode 中已创建或确认该 CloudKit container。
- Mac 和 iOS 使用同一个 Apple ID 登录 iCloud。
- iCloud Drive / CloudKit 未被系统限制。
- iOS target 的 Push Notifications 已启用。
- iOS target 的 Background Modes 已启用 Remote notifications，用于接收 CloudKit 后台变更通知。

## 进入 CloudKit 试运行

可用两种方式进入 CloudKit-backed store：

1. 启动参数 `--kite-sync-cloudkit`。
2. Mac 设置页同步区域或 iOS 同步页设置“下次启动”为 `iCloud / CloudKit`，然后重启 App。

启动参数优先于同步模式偏好。当前运行中的 store 不会热切换。
iOS 同步页会显示当前模式与下次启动模式是否一致；如果没有保存过同步偏好，“下次启动”会先跟随当前启动模式显示。
如果提示仍需重启，先重启再继续验证。
CloudKit 由系统后台调度；`导出完成` / `导入完成` 不是实时协同承诺。Mac 和 iOS 会在导入完成事件、回到前台或手动刷新时重读本地 Core Data。

Mac 主 UI 在 `iCloud / CloudKit` 模式下会自动读写主同步库。若只想在本地 Core Data 模式试运行 Mac 主同步库，可额外带启动参数：

```text
--kite-use-sync-store
```

首次把正式 Release JSON 播种到主同步库时，可再加：

```text
--kite-import-release-state
```

## Mac 侧确认

打开 Mac 设置页同步区域，确认：

- 当前模式显示 `iCloud / CloudKit`。
- 主同步库路径包含 `KiteNative-SyncCoreData-CloudKit`。
- Bundle ID 显示 `cn.kitlib.kitemac`。
- Container 显示 `iCloud.cn.kitlib.kite`。
- iCloud 账号检查显示可用。
- 同步事件出现准备、导入或导出状态。
- `写入同步标记` 在 CloudKit 模式可用；如果按钮不可用，说明当前仍在本地 Core Data 模式。

## iOS 侧确认

打开 iOS 同步页，确认：

- 当前模式显示 `iCloud / CloudKit`。
- 下次启动提示显示当前已使用 `iCloud / CloudKit`。
- 如果当前仍显示本地模式，先点 `下次启动用 iCloud / CloudKit` 并重启 iOS App。
- Store 路径包含 `KiteIOS-CoreData-CloudKit`。
- Bundle ID 显示 `cn.kitlib.kiteios`。
- Container 显示 `iCloud.cn.kitlib.kite`。
- iCloud 账号检查显示可用。
- 同步事件出现准备、导入或导出状态。

## 第一轮互通场景

### 标记互通

1. Mac 设置页同步区域点击 `主同步标记`，写入一个 `Mac主同步标记-日期-时间` 可见习惯到主同步库。
2. Mac 设置页观察 `导出中...` / `导出完成`。
3. iOS 同步页观察 `导入中...` / `导入完成`。
4. iOS 页面确认能看到 Mac 写入的同步标记。
5. iOS 同步页点击 `写入同步标记`，写入一个 `iOS同步标记-日期-时间` 可见习惯。
6. iOS 同步页确认 `最近标记` 显示刚写入的标题。
7. iOS 同步页观察 `导出完成`。
8. Mac 设置页观察 `导入完成`。
9. Mac 主 UI 同步库模式确认能看到 iOS 新增的测试习惯。

`实验标记` 按钮仍写入实验库，只用于实验库诊断；主同步验证使用 `主同步标记`。

### 正式数据播种验证

这一步会读取正式 Release JSON，并合并到当前 CloudKit-backed 主同步 Core Data store；不会删除或重置原始 JSON。
重复执行播种会更新已有同 key 记录，不会为了同一份 Release JSON 反复插入重复 habit entry、每日标题或隐藏记录。
iOS 空状态里的 `添加默认习惯` 只用于补齐缺失的默认习惯，不用于正式数据播种，也不会覆盖已有同步库数据。

1. Mac 设置页同步区域确认当前模式为 `iCloud / CloudKit`。
2. 点击 `导入主同步库`，或用 `--kite-import-release-state` 启动 Mac。
3. Mac 设置页观察 `导出中...` / `导出完成`。
4. iOS 同步页观察 `导入中...` / `导入完成`。
5. iOS 首页确认能看到 Mac 正式数据里的习惯和当天完成状态。
6. iOS 上新增或打卡一项测试数据。
7. Mac 设置页观察 `导入完成`。
8. Mac 主 UI 确认能看到 iOS 的改动。

## 失败时先看

- Team 是否为空。
- container 是否真的存在于 Apple Developer 账号下。
- Mac/iOS bundle id 是否属于同一个 Team。
- entitlements 是否被 Xcode 签进了实际 App。
- iOS 是否签入 `aps-environment`，以及 Push Notifications 是否在 Signing & Capabilities 中启用。
- 两端是否登录同一个 iCloud Apple ID。
- 网络是否可用。
- iCloud 账号检查是否显示具体失败原因。
- 同步事件是否显示失败消息。

当前验证不清理、不重置正式 Release JSON 数据；正式 App 本地默认数据源仍然是 JSON，Mac 进入 `iCloud / CloudKit` 模式后主 UI 会使用主同步库。
