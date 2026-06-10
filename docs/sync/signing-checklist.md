# Kite Signing Checklist

这份清单用于第一次真实 Mac / iOS CloudKit 验证前的人工签名准备。

## Xcode

1. 打开 `NativeMac/KiteNative.xcodeproj`。
2. 选择同一个 Apple Developer Team。
3. 把 Team ID 写回 `NativeMac/project.yml` 的 `DEVELOPMENT_TEAM`，避免下次 XcodeGen 重新生成项目时被覆盖回空值。
4. 重新生成项目：

```bash
cd NativeMac
xcodegen generate --spec project.yml
```

5. 确认 shared schemes 里有：
   - `KiteNative`
   - `KiteIOS`
6. 确认 bundle id：
   - Mac: `cn.kitlib.kitemac`
   - iOS: `cn.kitlib.kiteios`
7. 确认 Mac 和 iOS 都启用 iCloud / CloudKit capability。
8. 确认 iOS 启用 Push Notifications。
9. 确认 iOS 启用 Background Modes / Remote notifications。

## Apple Developer

1. 确认 CloudKit container 已存在：

```text
iCloud.cn.kitlib.kite
```

2. 确认 Mac 和 iOS bundle id 都属于同一个 Team。
3. 确认 Mac 和 iOS 都能使用同一个 CloudKit container。

## Local Check

签名配置前，静态检查会通过但提示 Team 为空：

```text
CloudKit static config checks passed.
CloudKit static config warnings: 2
```

把 Team ID 写入 `project.yml` 并重新生成项目后，再运行：

```bash
./scripts/verify-cloudkit-config.sh
```

目标是 `DEVELOPMENT_TEAM` 相关 warnings 归零，或只剩明确可接受的人工确认项。

## Runtime Verification

签名完成后，继续执行：

```text
docs/sync/cloudkit-verification.md
```

只有 Mac 和 iOS 在同一 iCloud Apple ID 下完成双向同步验证后，才能认为共享数据通路完成。
