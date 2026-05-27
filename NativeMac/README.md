# Native Mac App

This folder contains a native macOS implementation plan for Kite using:

- `SwiftUI + AppKit` for the main app
- `WidgetKit` for a desktop-style widget
- local JSON storage only

## What is included

- a small floating checklist app UI
- local persistence model
- shared widget data source structure
- an `XcodeGen` project spec you can generate later on a machine with full Xcode

## What is still required on this Mac

This machine currently has Swift command line tools, but not the full Xcode app.
To build and run the native app, install Xcode and then either:

1. install `xcodegen` and run `xcodegen generate`, or
2. recreate the same targets manually in Xcode

## Suggested bundle IDs

- App: `cn.kitlib.kitemac`
- Widget: `cn.kitlib.kitemac.widget`
- App Group: `group.cn.kitlib.kitemac`

Change them if you want.
