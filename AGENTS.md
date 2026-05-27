# Agent Notes

## Runtime habit

- After every code change to the NativeMac app, always do all of the following before reporting back:
  1. build the app with `xcodebuild -project /Users/dyliu/Desktop/software/kite-mac/NativeMac/KiteNative.xcodeproj -scheme KiteNative -configuration Debug build`
  2. quit any running `KiteNative` instance
  3. relaunch the latest built `KiteNative` app
  4. bring `KiteNative` to the foreground

- Do not stop after only editing files or only building. The expected workflow is edit -> build -> restart app -> foreground app.
