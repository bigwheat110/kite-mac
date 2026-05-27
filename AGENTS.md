# Agent Notes

## Runtime habit

- After every code change to the NativeMac app, always do all of the following before reporting back:
  1. build the app with `xcodebuild -project /Users/dyliu/Desktop/software/kite-mac/NativeMac/KiteNative.xcodeproj -scheme KiteNative -configuration Debug build`
  2. run UI tests with `xcodebuild test -project /Users/dyliu/Desktop/software/kite-mac/NativeMac/KiteNative.xcodeproj -scheme KiteNative -destination 'platform=macOS,arch=arm64'`
  3. quit any running `KiteNative` instance
  4. relaunch the latest built `KiteNative` app
  5. bring `KiteNative` to the foreground
  6. commit the current changes with a clear message
  7. push the commit to the GitHub remote `origin`

- Do not stop after only editing files or only building. The expected workflow is edit -> build -> ui-test -> restart app -> foreground app.
- Do not leave local-only changes behind after a completed edit cycle when the repository is in a healthy pushable state.
