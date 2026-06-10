#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NATIVE_DIR="$ROOT_DIR/NativeMac"

failures=0
warnings=0

check_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "ok: exists ${path#$ROOT_DIR/}"
  else
    echo "FAIL: missing ${path#$ROOT_DIR/}"
    failures=$((failures + 1))
  fi
}

check_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if grep -Eq "$pattern" "$path"; then
    echo "ok: $label"
  else
    echo "FAIL: $label"
    failures=$((failures + 1))
  fi
}

warn_if_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if grep -Eq "$pattern" "$path"; then
    echo "WARN: $label"
    warnings=$((warnings + 1))
  else
    echo "ok: $label"
  fi
}

check_project_yml_target_has_key() {
  local target="$1"
  local key="$2"
  local label="$3"
  if awk -v target="$target" -v key="$key" '
    $0 ~ "^  " target ":" { in_target = 1; next }
    in_target && $0 ~ "^  [A-Za-z0-9_]+:" { in_target = 0 }
    in_target && $0 ~ "^    " key ":" { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$NATIVE_DIR/project.yml"; then
    echo "ok: $label"
  else
    echo "FAIL: $label"
    failures=$((failures + 1))
  fi
}

check_plist_string() {
  local path="$1"
  local key="$2"
  local expected="$3"
  local label="$4"
  local actual
  actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$path" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    echo "ok: $label"
  else
    echo "FAIL: $label (expected '$expected', got '${actual:-<missing>}')"
    failures=$((failures + 1))
  fi
}

check_plist_array_contains() {
  local path="$1"
  local key="$2"
  local expected="$3"
  local label="$4"
  local values
  values="$(/usr/libexec/PlistBuddy -c "Print :$key" "$path" 2>/dev/null || true)"
  if [[ "$values" == *"$expected"* ]]; then
    echo "ok: $label"
  else
    echo "FAIL: $label"
    failures=$((failures + 1))
  fi
}

check_file "$NATIVE_DIR/project.yml"
check_file "$NATIVE_DIR/KiteNative.xcodeproj/project.pbxproj"
check_file "$NATIVE_DIR/KiteNative/KiteNative.entitlements"
check_file "$NATIVE_DIR/KiteIOS/KiteIOS.entitlements"
check_file "$NATIVE_DIR/KiteIOS/Info.plist"
check_file "$NATIVE_DIR/KiteIOS/Assets.xcassets/AppIcon.appiconset/Contents.json"
check_file "$NATIVE_DIR/KiteIOS/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
check_file "$NATIVE_DIR/KiteNative.xcodeproj/xcshareddata/xcschemes/KiteNative.xcscheme"
check_file "$NATIVE_DIR/KiteNative.xcodeproj/xcshareddata/xcschemes/KiteIOS.xcscheme"

echo
check_contains "$NATIVE_DIR/project.yml" "PRODUCT_BUNDLE_IDENTIFIER: cn\\.kitlib\\.kitemac" "Mac bundle id in project.yml"
check_contains "$NATIVE_DIR/project.yml" "PRODUCT_BUNDLE_IDENTIFIER: cn\\.kitlib\\.kiteios" "iOS bundle id in project.yml"
check_contains "$NATIVE_DIR/project.yml" "CODE_SIGN_ENTITLEMENTS: KiteNative/KiteNative\\.entitlements" "Mac entitlements configured"
check_contains "$NATIVE_DIR/project.yml" "CODE_SIGN_ENTITLEMENTS: KiteIOS/KiteIOS\\.entitlements" "iOS entitlements configured"
check_contains "$NATIVE_DIR/project.yml" "APS_ENVIRONMENT: development" "Debug APS environment configured"
check_contains "$NATIVE_DIR/project.yml" "APS_ENVIRONMENT: production" "Release APS environment configured"
check_contains "$NATIVE_DIR/project.yml" "INFOPLIST_FILE: KiteIOS/Info\\.plist" "iOS explicit Info.plist configured"
check_project_yml_target_has_key "KiteIOS" "scheme" "iOS scheme configured in project.yml"
warn_if_contains "$NATIVE_DIR/project.yml" 'DEVELOPMENT_TEAM: ""' "project.yml DEVELOPMENT_TEAM is empty; choose an Apple Developer Team before real CloudKit verification"

echo
check_contains "$NATIVE_DIR/Shared/HabitCoreDataStack.swift" 'cloudKitContainerIdentifier = "iCloud\.cn\.kitlib\.kite"' "shared CloudKit container constant"
check_contains "$NATIVE_DIR/Shared/HabitSyncStoreFactory.swift" 'directoryName = "KiteNative-SyncCoreData"' "Mac main sync store directory"
check_contains "$NATIVE_DIR/KiteIOS/KiteIOSCoreDataStoreFactory.swift" 'directoryName = "KiteIOS-CoreData"' "iOS Core Data store directory"
check_contains "$NATIVE_DIR/Shared/HabitStore.swift" 'from: appStateURL\(directoryName: "KiteNative"\)' "Mac sync bootstrap reads Release JSON"

echo
check_plist_string "$NATIVE_DIR/KiteIOS/KiteIOS.entitlements" "aps-environment" '$(APS_ENVIRONMENT)' "iOS aps-environment uses build setting"
check_plist_array_contains "$NATIVE_DIR/KiteIOS/KiteIOS.entitlements" "com.apple.developer.icloud-container-identifiers" "iCloud.cn.kitlib.kite" "iOS CloudKit container entitlement"
check_plist_array_contains "$NATIVE_DIR/KiteIOS/KiteIOS.entitlements" "com.apple.developer.icloud-services" "CloudKit" "iOS CloudKit service entitlement"
check_plist_array_contains "$NATIVE_DIR/KiteNative/KiteNative.entitlements" "com.apple.developer.icloud-container-identifiers" "iCloud.cn.kitlib.kite" "Mac CloudKit container entitlement"
check_plist_array_contains "$NATIVE_DIR/KiteNative/KiteNative.entitlements" "com.apple.developer.icloud-services" "CloudKit" "Mac CloudKit service entitlement"
check_plist_array_contains "$NATIVE_DIR/KiteIOS/Info.plist" "UIBackgroundModes" "remote-notification" "iOS remote notification background mode"

echo
check_contains "$NATIVE_DIR/KiteNative.xcodeproj/project.pbxproj" "PRODUCT_BUNDLE_IDENTIFIER = cn\\.kitlib\\.kiteios;" "iOS bundle id in xcodeproj"
check_contains "$NATIVE_DIR/KiteNative.xcodeproj/project.pbxproj" "CODE_SIGN_ENTITLEMENTS = KiteIOS/KiteIOS\\.entitlements;" "iOS entitlements in xcodeproj"
check_contains "$NATIVE_DIR/KiteNative.xcodeproj/project.pbxproj" "APS_ENVIRONMENT = development;" "Debug APS environment in xcodeproj"
check_contains "$NATIVE_DIR/KiteNative.xcodeproj/project.pbxproj" "APS_ENVIRONMENT = production;" "Release APS environment in xcodeproj"
check_contains "$NATIVE_DIR/KiteNative.xcodeproj/project.pbxproj" "Assets\\.xcassets in Resources" "iOS asset catalog in resources"
warn_if_contains "$NATIVE_DIR/KiteNative.xcodeproj/project.pbxproj" 'DEVELOPMENT_TEAM = "";' "xcodeproj DEVELOPMENT_TEAM is empty; regenerate after choosing an Apple Developer Team"
check_contains "$NATIVE_DIR/KiteNative.xcodeproj/xcshareddata/xcschemes/KiteNative.xcscheme" 'BuildableName = "KiteNative\.app"' "Mac shared scheme launches KiteNative"
check_contains "$NATIVE_DIR/KiteNative.xcodeproj/xcshareddata/xcschemes/KiteIOS.xcscheme" 'BuildableName = "KiteIOS\.app"' "iOS shared scheme launches KiteIOS"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "CloudKit static config checks passed."
  if [[ "$warnings" -gt 0 ]]; then
    echo "CloudKit static config warnings: $warnings"
  fi
else
  echo "CloudKit static config checks failed: $failures"
  exit 1
fi
