# Kite Native

This folder contains the native Apple implementation of Kite:

- `KiteNative`: macOS app built with SwiftUI + AppKit.
- `KiteWidgetExtension`: macOS WidgetKit extension scaffold.
- `KiteIOS`: iPhone SwiftUI app target.
- `Shared`: shared habit models, Core Data stack, Core Data store, and CloudKit diagnostics used by Mac and iOS.

## Data Stores

Current production Mac data remains the local JSON file:

```text
~/Library/Application Support/KiteNative/app-state.json
```

Debug Mac data remains isolated from Release data:

```text
~/Library/Application Support/KiteNative-Debug/app-state.json
```

CloudKit trial mode uses shared Core Data models and a shared CloudKit container:

```text
iCloud.cn.kitlib.kite
```

Mac uses the main sync store when launched in `iCloud / CloudKit` mode, or when `--kite-use-sync-store` is supplied:

```text
~/Library/Application Support/KiteNative-SyncCoreData/kite-sync-core-data.sqlite
~/Library/Application Support/KiteNative-SyncCoreData-CloudKit/kite-sync-core-data.sqlite
```

iOS uses its own local Core Data cache for the same CloudKit-backed model:

```text
~/Library/Application Support/KiteIOS-CoreData/kite-ios-core-data.sqlite
~/Library/Application Support/KiteIOS-CoreData-CloudKit/kite-ios-core-data.sqlite
```

## CloudKit Trial

CloudKit-backed mode can be enabled with:

```text
--kite-sync-cloudkit
```

The Mac app can also seed the main sync store from the Release JSON with:

```text
--kite-import-release-state
```

This import is merge-based and does not delete or reset the original Release JSON.

Before building for real device verification, run:

```bash
bash ../scripts/verify-cloudkit-config.sh
```

## Signing

`project.yml` currently leaves `DEVELOPMENT_TEAM` empty. Before real CloudKit verification, choose the same Apple Developer Team for:

- Mac bundle id: `cn.kitlib.kitemac`
- iOS bundle id: `cn.kitlib.kiteios`

Both targets must use the same CloudKit container:

```text
iCloud.cn.kitlib.kite
```

iOS also needs Push Notifications and Background Modes / Remote notifications enabled for Core Data + CloudKit background imports.

## Verification

The current code path is implemented but not yet proven by real CloudKit runtime evidence. Follow:

```text
../docs/sync/cloudkit-verification.md
```

The goal is not complete until Mac and iOS are signed, built, run with the same iCloud account, and verified to sync data in both directions.
