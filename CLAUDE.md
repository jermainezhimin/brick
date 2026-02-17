# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
# Build for development (debug)
swift build

# Build for release
swift build -c release

# Run the app
.build/release/Brick

# Clean build artifacts
swift package clean

# Update dependencies (if any are added)
swift package update
```

## Architecture Overview

### State Management Pattern

**AppSettings** is the central state manager and acts as the coordinator between UI and system managers:

- Single `@StateObject` created in `BrickApp` and passed via `@EnvironmentObject`
- Uses `@Published` properties with `didSet` observers that trigger side effects
- Directly calls singleton managers (`GrayscaleManager.shared`, `ProxyManager.shared`)
- Handles error recovery by reverting toggle state on failure
- Persists all settings to `UserDefaults` automatically in `didSet`
- Re-applies system state on initialization (grayscale, blocking) from saved settings

**Key pattern**: Toggle changes → `didSet` fires → Manager call → On error, revert toggle state and show error

### Manager Architecture

All managers follow the singleton pattern with `@MainActor` isolation:

1. **GrayscaleManager**:
   - Captures original display gamma tables before modification
   - Stores them in `originalGammas` dictionary keyed by display ID
   - Applies grayscale using luminance formula: `0.299*R + 0.587*G + 0.114*B`
   - Registers display reconfiguration callback to handle display connect/disconnect
   - Must re-apply on wake (handled by `AppSettings` via `NSWorkspace.screensDidWakeNotification`)

2. **ProxyManager**:
   - Generates PAC (Proxy Auto-Configuration) JavaScript file
   - Saves to `~/Library/Application Support/Brick/proxy.pac`
   - Uses `SystemConfiguration` framework to modify system-wide proxy settings
   - Requires admin authorization via `AuthManager` before each proxy modification
   - Iterates through all network services to apply/remove PAC configuration

3. **AuthManager**:
   - Wraps macOS `AuthorizationServices` API
   - Caches `AuthorizationRef` after first successful authorization
   - Uses `withCheckedThrowingContinuation` to bridge callback-based API to async/await
   - Authorization request runs on background queue to avoid blocking main thread

### Async/Await Error Handling

Website blocking uses async operations that can fail. The pattern:

```swift
// In AppSettings.isBlockingEnabled.didSet:
Task {
    do {
        try await ProxyManager.shared.enableBlocking(domains: blockedSites)
    } catch {
        await MainActor.run {
            self.isBlockingEnabled = previousValue  // Revert toggle
            self.errorMessage = error.localizedDescription
        }
    }
}
```

This ensures UI state stays synchronized with actual system state.

### Critical Constraints

1. **App Sandbox Must Be Disabled**: `Brick.entitlements` sets `com.apple.security.app-sandbox` to `false` because:
   - `SystemConfiguration` framework requires direct system access
   - PAC file modification needs unrestricted file I/O
   - Cannot distribute via Mac App Store with this configuration

2. **Main Actor Isolation**: All managers are `@MainActor` isolated because:
   - They modify UI-bound state (gamma tables affect visible display)
   - They're called from SwiftUI property observers
   - Prevents data races on shared state

3. **No Deinit on GrayscaleManager**: Originally had `deinit` calling `disableGrayscale()`, but removed because:
   - `deinit` cannot call `@MainActor` methods (synchronous context)
   - Manager is a singleton that lives for app lifetime
   - Grayscale persists until explicitly disabled (acceptable UX)

4. **Authorization String Handling**: `AuthManager` must use `withCString` to pass authorization rights:
   - Swift String → `UnsafePointer<Int8>` conversion is temporary
   - Must extend pointer lifetime through the authorization call
   - Failure to do so causes memory safety warnings/crashes

## File Organization

```
Sources/Brick/
├── BrickApp.swift              # Entry point, MenuBarExtra setup
├── Models/
│   └── AppSettings.swift       # Central state + coordinator
├── Managers/
│   ├── GrayscaleManager.swift  # Display gamma manipulation
│   ├── ProxyManager.swift      # PAC file + SystemConfiguration
│   └── AuthManager.swift       # Authorization wrapper
└── Views/
    ├── MenuBarView.swift       # Menu bar popup UI
    └── SettingsView.swift      # Blocked sites management
```

## Working with System APIs

### SystemConfiguration Framework

When modifying proxy code in `ProxyManager`:

1. Must lock preferences: `SCPreferencesLock(prefs, true)`
2. Iterate through network services: `SCNetworkServiceCopyAll(prefs)`
3. Only modify enabled services: `SCNetworkServiceGetEnabled(service)`
4. Get protocols for each service: `SCNetworkServiceCopyProtocols(service)`
5. Modify IPv4/IPv6 protocol configurations
6. Commit changes: `SCPreferencesCommitChanges(prefs)`
7. Apply changes: `SCPreferencesApplyChanges(prefs)`
8. Always unlock in `defer`: `SCPreferencesUnlock(prefs)`

### CoreGraphics Display APIs

When modifying grayscale code in `GrayscaleManager`:

1. Get active displays: `CGGetActiveDisplayList(displayCount, &displays, &displayCount)`
2. Query gamma capacity: `CGGetDisplayTransferByTable(displayID, 0, nil, nil, nil, &capacity)`
3. Allocate arrays of `CGGammaValue` with exact capacity
4. Read current gamma: `CGGetDisplayTransferByTable(displayID, capacity, &red, &green, &blue, &capacity)`
5. Apply new gamma: `CGSetDisplayTransferByTable(displayID, capacity, gray, gray, gray)`
6. Always store original gamma before modifying (cannot query "default" gamma)

## macOS Version Requirements

- **Minimum**: macOS 13.0 (Ventura)
- **Reason**: `MenuBarExtra` SwiftUI API introduced in macOS 13
- **Alternative**: For older OS support, use AppKit `NSStatusItem` + `NSPopover` hybrid approach

## Testing Considerations

Currently no automated tests. When adding tests:

- Cannot test `GrayscaleManager` in CI (requires physical display)
- Cannot test `ProxyManager` in CI (requires admin privileges)
- Can test: PAC file generation logic (extract to pure function)
- Can test: Domain validation in `SettingsView`
- Can test: `AppSettings` state transitions with mock managers

## Common Gotchas

1. **Preview Macros Don't Work**: `#Preview` requires PreviewsMacros plugin, not available in SPM executable targets. Remove all `#Preview` blocks.

2. **Grayscale Resets on Sleep**: By design. `AppSettings` re-applies via `NSWorkspace.screensDidWakeNotification` observer.

3. **Authorization Dialog Language**: macOS shows generic "application wants to make changes" prompt. Cannot customize the message text.

4. **PAC File Limitations**: PAC files only affect HTTP/HTTPS. Apps using direct socket connections bypass the proxy.

5. **UserDefaults Keys**: All settings keys are string literals in `AppSettings`. Keep them synchronized:
   - `isGrayscaleEnabled`
   - `isBlockingEnabled`
   - `blockedSites`
