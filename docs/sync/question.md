# Kite CloudKit 同步待确认问题

这份清单只记录当前还会影响真实 Mac / iOS 互通验证的事项；已落地的决策不再作为开放问题保留。

## Apple 能力

- 是否已有可用 Apple Developer 账号？当前 `NativeMac/project.yml` 里的 `DEVELOPMENT_TEAM` 仍为空。
- Apple Developer / Xcode 中是否已创建并启用 CloudKit container `iCloud.cn.kitlib.kite`？
- Mac target `cn.kitlib.kitemac` 和 iOS target `cn.kitlib.kiteios` 是否都签到同一个 Team？
- 真机或模拟器是否使用同一个 Apple ID 登录 iCloud，且 iCloud / CloudKit 未被系统限制？

## 已决策

- 同步主线使用 Core Data + CloudKit + `NSPersistentCloudKitContainer`。
- 第一版同步范围只覆盖习惯、打卡、每日改名、隐藏、重复规则和排序。
- 提醒、专注状态和 UI 偏好暂不进入第一版同步范围。
- Mac 正式 JSON 可以复制到实验库或主同步库；不删除、不重置原始 Release JSON。
- iOS 首版不是只读版，已支持新增、打卡、改名、隐藏、删除、重复规则、排序和同步标记。
- Mac 设置页和 iOS 同步页都显示 iCloud 账号、CloudKit container、当前/下次同步模式、最近同步事件。

## 仍需验证

- Mac 设置页切到 `iCloud / CloudKit` 并重启后，主 UI 是否稳定读写 `KiteNative-SyncCoreData-CloudKit`。
- Mac 将正式 Release JSON 导入主同步库后，iOS 是否能在同一 Apple ID 下导入并显示当天数据。
- iOS 新增、打卡、改名、隐藏、删除和排序后，Mac 主 UI 是否能看到变化。
- 两端同时编辑同一个习惯时，系统合并结果是否符合第一版可接受预期。
- CloudKit 失败事件的错误文本是否足够指导用户排查 Team、container、Apple ID 和网络问题。

## 未来路线

- 是否需要把提醒同步纳入第二阶段。
- 是否需要 Windows / Android / Web。
- 是否需要多人共享习惯。
- 如果以后要商业化，是否重新评估自建后端。
