# Kite Apple Apps

This repository contains the native Apple implementation of Kite:

- macOS app: `NativeMac/KiteNative`
- iPhone app target: `NativeMac/KiteIOS`
- shared habit/Core Data/CloudKit code: `NativeMac/Shared`
- XcodeGen spec: `NativeMac/project.yml`

The Mac app's default production data source is still the local JSON file. The iOS app and the Mac sync mode use shared Core Data models, with CloudKit-backed stores available through `iCloud.cn.kitlib.kite`.

Before signing or device verification, run:

```bash
bash scripts/verify-cloudkit-config.sh
```

CloudKit verification still requires Apple Developer signing, a confirmed CloudKit container, and real Mac/iOS runtime testing with the same iCloud account.

More detail:

- [NativeMac/README.md](NativeMac/README.md)
- [docs/sync/architecture.md](docs/sync/architecture.md)
- [docs/sync/signing-checklist.md](docs/sync/signing-checklist.md)
- [docs/sync/cloudkit-verification.md](docs/sync/cloudkit-verification.md)
