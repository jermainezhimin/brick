# macOS Site Blocker + Grayscale App - Implementation Plan

## Overview
Create a native macOS menu bar application that:
1. Blocks access to distracting websites system-wide
2. Toggles screen grayscale mode
3. Provides simple on/off controls

## Technical Approach

### Architecture
- **Language**: Swift
- **Framework**: SwiftUI with MenuBarExtra
- **App Type**: Menu bar application (macOS 13+)
- **Minimum OS**: macOS 13.0+ (Ventura)
- **Sandbox**: Disabled (required for system configuration access)

### Key Components

#### 1. Site Blocking
**Approach**: PAC (Proxy Auto-Configuration) File
- **Why not hosts file?**: Requires SIP bypass, poor UX with authentication prompts
- **Why PAC?**: System-wide HTTP/HTTPS blocking, standard macOS mechanism

**Implementation**:
```swift
class ProxyManager {
    func enableBlocking(domains: [String]) {
        // Generate PAC JavaScript file
        let pacScript = generatePAC(blockedDomains: domains)
        let pacURL = savePACFile(content: pacScript)

        // Set system proxy using SystemConfiguration framework
        // Requires one-time admin authorization via AuthorizationServices
        let proxyConfig: NSDictionary = [
            kCFNetworkProxiesProxyAutoConfigEnable: true,
            kCFNetworkProxiesProxyAutoConfigURLString: pacURL.absoluteString
        ]

        SCPreferencesSetValue(prefs, kSCPrefNetworkServices, proxyConfig)
    }

    private func generatePAC(blockedDomains: [String]) -> String {
        // JavaScript function that redirects blocked domains to dead proxy
        return """
        function FindProxyForURL(url, host) {
            var blocked = [\(domainList)];
            for (var i = 0; i < blocked.length; i++) {
                if (dnsDomainIs(host, blocked[i])) {
                    return "PROXY 127.0.0.1:1";  // Black hole
                }
            }
            return "DIRECT";
        }
        """
    }
}
```

**Default blocked sites** (user can customize):
- facebook.com, twitter.com, instagram.com
- reddit.com, youtube.com, tiktok.com
- news sites, entertainment sites

#### 2. Grayscale Toggle
**Approach**: Use Core Graphics Display Gamma Tables
- **Why not CGDisplaySetDisplayColorSpace?**: Deprecated API
- **Why gamma tables?**: Works on all macOS versions, no special permissions

**Implementation**:
```swift
class GrayscaleManager {
    private var originalGammas: [CGDirectDisplayID: (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])] = [:]

    func enableGrayscale() {
        let displays = getActiveDisplays()

        for displayID in displays {
            // Save original gamma tables
            var capacity: UInt32 = 0
            CGGetDisplayTransferByTable(displayID, 0, nil, nil, nil, &capacity)

            var redTable = [CGGammaValue](repeating: 0, count: Int(capacity))
            var greenTable = [CGGammaValue](repeating: 0, count: Int(capacity))
            var blueTable = [CGGammaValue](repeating: 0, count: Int(capacity))

            CGGetDisplayTransferByTable(displayID, capacity, &redTable, &greenTable, &blueTable, &capacity)
            originalGammas[displayID] = (redTable, greenTable, blueTable)

            // Create grayscale using luminance formula
            var grayTable = [CGGammaValue](repeating: 0, count: Int(capacity))
            for i in 0..<Int(capacity) {
                let gray = 0.299 * redTable[i] + 0.587 * greenTable[i] + 0.114 * blueTable[i]
                grayTable[i] = gray
            }

            // Apply grayscale to all channels
            CGSetDisplayTransferByTable(displayID, capacity, grayTable, grayTable, grayTable)
        }
    }

    func disableGrayscale() {
        // Restore original gamma tables
        for (displayID, gamma) in originalGammas {
            CGSetDisplayTransferByTable(displayID, UInt32(gamma.red.count), gamma.red, gamma.green, gamma.blue)
        }
        originalGammas.removeAll()
    }
}
```

**Handle display sleep/wake**:
```swift
// Register for wake notifications to re-apply grayscale
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.screensDidWakeNotification,
    object: nil,
    queue: .main
) { _ in
    if isGrayscaleEnabled {
        grayscaleManager.enableGrayscale()
    }
}
```

#### 3. Menu Bar Interface
**Using SwiftUI MenuBarExtra** (macOS 13+):
```swift
@main
struct ShooterApp: App {
    var body: some Scene {
        MenuBarExtra("Shooter", systemImage: "shield.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
```

**Menu content**:
- Enable/Disable Site Blocking (toggle)
- Enable/Disable Grayscale (toggle)
- Divider
- Configure Blocked Sites... (opens settings window)
- Divider
- Quit

#### 4. Settings Window
- SwiftUI List of blocked sites
- Add/Remove buttons
- Text field for adding new domains
- Persist settings in UserDefaults
- Default sites pre-populated

### Project Structure
```
shooter/
├── Package.swift                  # Swift Package Manager manifest
├── Sources/
│   └── Shooter/
│       ├── ShooterApp.swift           # App entry point with MenuBarExtra
│       ├── Views/
│       │   ├── MenuBarView.swift      # Main menu UI (toggles, settings button)
│       │   └── SettingsView.swift     # Blocked sites configuration window
│       ├── Managers/
│       │   ├── GrayscaleManager.swift # Display gamma manipulation
│       │   ├── ProxyManager.swift     # PAC file generation & system config
│       │   ├── AuthManager.swift      # Authorization Services wrapper
│       │   └── PersistenceManager.swift # UserDefaults wrapper
│       ├── Models/
│       │   └── AppSettings.swift      # Settings data model
│       └── Resources/
│           └── Assets.xcassets/       # App icon
├── Shooter.entitlements           # App permissions (sandbox disabled)
└── README.md
```

## Implementation Steps

### Phase 1: Project Setup
1. Create Swift Package with executable target
2. Add Package.swift with macOS 13+ platform requirement
3. Create Shooter.entitlements with sandbox disabled
4. Set up basic project structure (Sources/Shooter/)

### Phase 2: Menu Bar Interface
1. Create `ShooterApp.swift` with MenuBarExtra
   - Use SwiftUI MenuBarExtra API
   - Set menu bar icon (SF Symbol "shield.fill")
   - Configure .window style for custom UI
2. Create `MenuBarView.swift`
   - Site blocking toggle
   - Grayscale toggle
   - Configure Sites button
   - Quit button
3. Create view model for state management

### Phase 3: Grayscale Feature
1. Implement `GrayscaleManager.swift`
   - `getActiveDisplays()` - enumerate all displays
   - `enableGrayscale()` - save original gamma tables, apply grayscale
   - `disableGrayscale()` - restore original gamma tables
   - Use CGGetDisplayTransferByTable/CGSetDisplayTransferByTable
2. Handle display configuration changes
   - Register CGDisplayRegisterReconfigurationCallback
   - Re-apply grayscale when displays connect/disconnect
3. Handle wake from sleep
   - Register NSWorkspace.screensDidWakeNotification
   - Re-apply grayscale after wake
4. Wire up to menu bar toggle
5. Persist state in UserDefaults

### Phase 4: Site Blocking - PAC File Approach
1. Implement `ProxyManager.swift`
   - `generatePAC(blockedDomains:)` - create JavaScript PAC file
   - `savePACFile(content:)` - write to app support directory
   - `enableBlocking()` - set system proxy via SystemConfiguration
   - `disableBlocking()` - remove PAC configuration, restore direct
2. Implement `AuthManager.swift`
   - Wrap AuthorizationServices API
   - Request admin privileges for SCPreferences changes
   - Handle authorization errors gracefully
3. Create default blocked sites list
4. Wire up to menu bar toggle

### Phase 5: Settings Window
1. Create `SettingsView.swift`
   - SwiftUI List showing blocked domains
   - TextField for adding new domains
   - Delete gesture/button for removing domains
   - Pre-populate with default sites
2. Implement `PersistenceManager.swift`
   - Save/load blocked sites array to UserDefaults
   - Validate domain format
3. Create `AppSettings.swift` model
   - Observable object for app state
   - Blocked sites array
   - Feature toggle states
4. Connect settings button to open window

### Phase 6: Error Handling & Edge Cases
1. Handle authorization failures
   - Show alert if user denies admin access
   - Disable site blocking if authorization fails
2. Handle PAC file I/O errors
3. Handle grayscale failures on unsupported displays
4. Test with multiple monitors
5. Test sleep/wake cycles

### Phase 7: Polish
1. Create app icon
2. Add launch at login capability (optional)
3. Add notification when blocking is bypassed
4. Add keyboard shortcuts (optional)
5. Build and test on clean macOS install

## Critical Files to Create

1. **Package.swift** - Swift Package Manager manifest, macOS 13+ platform
2. **Sources/Shooter/ShooterApp.swift** - App entry point with MenuBarExtra
3. **Sources/Shooter/Views/MenuBarView.swift** - Main menu UI with toggles
4. **Sources/Shooter/Managers/GrayscaleManager.swift** - Display gamma manipulation
5. **Sources/Shooter/Managers/ProxyManager.swift** - PAC file generation and system proxy config
6. **Sources/Shooter/Managers/AuthManager.swift** - Authorization Services wrapper
7. **Sources/Shooter/Managers/PersistenceManager.swift** - UserDefaults persistence
8. **Sources/Shooter/Models/AppSettings.swift** - Observable settings model
9. **Sources/Shooter/Views/SettingsView.swift** - Blocked sites configuration UI
10. **Shooter.entitlements** - App permissions (sandbox: false)

## Permissions & Entitlements

**Shooter.entitlements**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Disable sandbox for SystemConfiguration access -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

**Required permissions**:
- **Admin privileges**: One-time password prompt for PAC configuration via SystemConfiguration
- **No special entitlements**: Grayscale feature works without any special permissions

**Note**: App sandbox must be disabled to use SystemConfiguration framework for system-wide proxy settings

## Verification Plan

### Build & Run
1. Build Swift package: `swift build -c release`
2. Run executable: `.build/release/Shooter`
3. Or use Xcode to generate .app bundle

### Manual Testing

#### 1. Menu Bar App
- Launch app, verify shield icon appears in menu bar
- Click icon, verify menu window opens
- Verify UI shows:
  - Site blocking toggle (off by default)
  - Grayscale toggle (off by default)
  - Configure Sites button
  - Quit button
- Verify toggles are interactive

#### 2. Grayscale Feature
- Enable grayscale toggle
- Verify entire screen (all displays) turns grayscale
- Open Photos/Safari to confirm colors are removed
- Disable toggle
- Verify full color returns
- **Sleep/wake test**:
  - Enable grayscale
  - Put Mac to sleep
  - Wake Mac
  - Verify grayscale is re-applied automatically
- **Multiple displays**:
  - Connect second display
  - Enable grayscale
  - Verify both displays are grayscale
  - Disconnect second display
  - Verify grayscale persists on primary

#### 3. Site Blocking (PAC File)
- Enable site blocking toggle
- Enter admin password when prompted
- Open System Settings > Network > [Active Connection] > Details > Proxies
- Verify "Automatic Proxy Configuration" is enabled
- Verify PAC URL points to app's PAC file
- **Browser testing**:
  - Open Safari, try accessing facebook.com
  - Verify connection fails (can't reach site)
  - Try Chrome, Firefox - verify blocking works across all browsers
  - Try direct IP access - verify PAC blocks domain-based access
- Disable site blocking toggle
- Verify System Settings shows proxy is disabled
- Verify blocked sites are now accessible

#### 4. Settings Window
- Click "Configure Sites..." button
- Verify settings window opens
- Verify default blocked sites are listed:
  - facebook.com, twitter.com, instagram.com
  - reddit.com, youtube.com, tiktok.com
- **Add domain**:
  - Enter "example.com" in text field
  - Click Add button
  - Verify domain appears in list
- **Remove domain**:
  - Select a domain
  - Click Delete button or swipe to delete
  - Verify domain is removed
- Close settings window
- Quit and relaunch app
- Open settings again
- Verify changes persisted

#### 5. State Persistence
- Enable both grayscale and site blocking
- Quit app completely
- Relaunch app
- Verify menu shows both toggles are ON
- Verify grayscale is active
- Verify sites are still blocked (check System Settings)

#### 6. Error Handling
- **Authorization failure**:
  - Enable site blocking
  - Click "Cancel" on admin password prompt
  - Verify app shows error alert
  - Verify toggle returns to OFF state
  - Verify proxy settings unchanged
- **Invalid domain**:
  - Try adding "not a domain" to blocked list
  - Verify validation error or graceful handling

## Alternative Approaches Considered

### For Site Blocking

1. **Hosts File Modification** ❌
   - **Rejected**: Requires SIP bypass, poor user experience with frequent admin prompts, DNS cache issues

2. **Network Extension (NEFilterDataProvider)** 🔄
   - **Future consideration**: Professional-grade system-wide blocking at socket level
   - Requires System Extension entitlement and user approval in System Settings
   - More complex but better for v2.0 if needed

3. **Local HTTP Proxy Server** ⚠️
   - User-space proxy without admin access
   - Only works if apps respect system proxy settings
   - Less effective than PAC or Network Extension

4. **PAC (Proxy Auto-Configuration) File** ✅
   - **Selected**: Standard macOS mechanism, works across all browsers, single admin authorization

### For Grayscale

1. **CGDisplaySetDisplayColorSpace** ❌
   - **Rejected**: Deprecated API, unreliable on modern macOS

2. **Accessibility Display Filter API** ⚠️
   - Private APIs, may require accessibility permissions
   - More fragile due to private API usage

3. **CGSetDisplayTransferByTable (Gamma Tables)** ✅
   - **Selected**: Reliable, no special permissions, works on all macOS versions, supports multiple displays

## Technical Risks & Mitigations

1. **Risk**: PAC settings can be disabled by user in System Settings
   - **Mitigation**: Monitor for changes, notify user if blocking is bypassed

2. **Risk**: Grayscale resets on display sleep/wake
   - **Mitigation**: Register for wake notifications and re-apply automatically

3. **Risk**: Display configuration changes (connect/disconnect monitors)
   - **Mitigation**: Register CGDisplayRegisterReconfigurationCallback to handle display changes

4. **Risk**: Authorization denied by user
   - **Mitigation**: Graceful error handling, clear messaging, toggle returns to OFF state

## Future Enhancements

- Scheduled blocking (enable during work hours)
- "Focus Mode" that enables both features with one click
- Statistics/analytics (time saved, sites blocked count)
- Whitelist mode (block all except specific sites)
- Temporary "break" period (5-10 minutes)
- Launch at login option
- Keyboard shortcuts for quick toggle

## Summary

This plan implements a macOS 13+ menu bar app using:
- **SwiftUI MenuBarExtra** for clean, native menu bar integration
- **PAC file approach** for reliable system-wide site blocking
- **Display gamma tables** for grayscale without special permissions
- **Swift Package Manager** for simple project structure
- **Disabled app sandbox** to allow SystemConfiguration access

The implementation prioritizes:
1. ✅ Simple user experience (one-time admin authorization)
2. ✅ Reliable system-wide blocking (all browsers, all apps)
3. ✅ No special entitlements required (except disabled sandbox)
4. ✅ Graceful error handling
5. ✅ State persistence across app restarts
6. ✅ Multiple display support for grayscale
