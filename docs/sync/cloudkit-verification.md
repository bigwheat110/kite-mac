# Kite CloudKit 验证清单

这份清单用于第一次验证 Mac / iOS 是否能通过同一个 iCloud 私有库同步。

## 前置配置

- Xcode Signing Team 已选择同一个 Apple Developer Team。
- Mac target bundle id: `cn.kitlib.kitemac`。
- iOS target bundle id: `cn.kitlib.kiteios`。
- Mac entitlement: `NativeMac/KiteNative/KiteNative.entitlements`。
- iOS entitlement: `NativeMac/KiteIOS/KiteIOS.entitlements`。
- 两个 entitlement 都包含同一个 container:

```text
iCloud.cn.kitlib.kite
```

- Apple Developer / Xcode 中已创建或确认该 CloudKit container。
- Mac 和 iOS 使用同一个 Apple ID 登录 iCloud。
- iCloud Drive / CloudKit 未被系统限制。

## 进入 CloudKit 试运行

可用两种方式进入 CloudKit-backed store：

1. 启动参数 `--kite-sync-cloudkit`。
2. Debug 面板或 iOS 同步页设置“下次启动”为 `iCloud / CloudKit`，然后重启 App。

启动参数优先于 Debug 偏好。当前运行中的 store 不会热切换。

## Mac 侧确认

打开 Mac Debug Core Data 实验面板，确认：

- 当前模式显示 `iCloud / CloudKit`。
- Store 路径包含 `KiteNative-CoreDataExperiment-CloudKit`。
- Bundle ID 显示 `cn.kitlib.kitemac`。
- Container 显示 `iCloud.cn.kitlib.kite`。
- iCloud 账号检查显示可用。
- 同步事件出现准备、导入或导出状态。

## iOS 侧确认

打开 iOS 同步页，确认：

- 当前模式显示 `iCloud / CloudKit`。
- Store 路径包含 `KiteIOS-CoreData-CloudKit`。
- Bundle ID 显示 `cn.kitlib.kiteios`。
- Container 显示 `iCloud.cn.kitlib.kite`。
- iCloud 账号检查显示可用。
- 同步事件出现准备、导入或导出状态。

## 第一轮互通场景

1. Mac Debug 面板点击 `同步标记`，写入一个 `Mac同步标记-日期-时间` 可见习惯。
2. Mac 面板观察 `导出中...` / `导出完成`。
3. iOS 同步页观察 `导入中...` / `导入完成`。
4. iOS 页面确认能看到 Mac 写入的同步标记。
5. iOS 同步页点击 `写入同步标记`，写入一个 `iOS同步标记-日期-时间` 可见习惯。
6. iOS 同步页观察 `导出完成`。
7. Mac 面板观察 `导入完成`。
8. Mac Core Data 试运行模式确认能看到 iOS 新增的测试习惯。

## 失败时先看

- Team 是否为空。
- container 是否真的存在于 Apple Developer 账号下。
- Mac/iOS bundle id 是否属于同一个 Team。
- entitlements 是否被 Xcode 签进了实际 App。
- 两端是否登录同一个 iCloud Apple ID。
- 网络是否可用。
- iCloud 账号检查是否显示具体失败原因。
- 同步事件是否显示失败消息。

当前验证只面向 Debug / 实验库，不迁移、不清理、不重置正式 Release JSON 数据。
