# Brick

A macOS menu bar application that helps you stay focused by blocking distracting websites and reducing visual stimulation with grayscale mode.

## Features

- **Website Blocking**: System-wide blocking of distracting websites across all browsers
- **Grayscale Mode**: Convert your entire screen to grayscale to reduce visual distractions
- **Customizable Block List**: Add or remove websites from the blocked list
- **Persistent Settings**: Your preferences are saved and restored between app sessions
- **Multi-Display Support**: Grayscale mode works across all connected displays
- **Auto-Recovery**: Grayscale automatically re-applies after waking from sleep

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd brick
   ```

2. Build the project:
   ```bash
   swift build -c release
   ```

3. The executable will be at `.build/release/Brick`

### Running the App

```bash
.build/release/Brick
```

Or double-click the executable in Finder.

## Usage

### Menu Bar Interface

Once launched, Brick appears as a shield icon in your menu bar. Click the icon to access:

- **Block Websites** toggle - Enable/disable website blocking
- **Grayscale Mode** toggle - Enable/disable screen grayscale
- **Configure Sites...** - Manage your blocked websites list
- **Quit Brick** - Exit the application

### Website Blocking

1. Click the shield icon in the menu bar
2. Toggle "Block Websites" on
3. Enter your admin password when prompted (one-time authorization)
4. Blocked websites will now be inaccessible across all browsers

**Default blocked sites:**
- facebook.com
- twitter.com / x.com
- instagram.com
- reddit.com
- youtube.com
- tiktok.com
- netflix.com
- twitch.tv

### Managing Blocked Sites

1. Click "Configure Sites..." in the menu
2. Add new sites by entering the domain (e.g., `example.com`) and clicking the + button
3. Remove sites by selecting them and pressing Delete or clicking the delete button
4. Changes take effect immediately if blocking is enabled

### Grayscale Mode

1. Click the shield icon in the menu bar
2. Toggle "Grayscale Mode" on
3. Your screen(s) will instantly convert to grayscale
4. Toggle off to restore full color

**Note**: Grayscale automatically re-applies after your Mac wakes from sleep.

## How It Works

### Website Blocking

Brick uses a PAC (Proxy Auto-Configuration) file to block websites at the system level. When you enable blocking:

1. Brick generates a PAC JavaScript file with your blocked domains
2. The PAC file is saved to `~/Library/Application Support/Brick/proxy.pac`
3. macOS system proxy settings are configured to use this PAC file
4. Any attempt to access blocked domains is redirected to a non-existent proxy

This approach works across:
- All web browsers (Safari, Chrome, Firefox, Edge, etc.)
- All apps that respect system proxy settings
- HTTP and HTTPS traffic

### Grayscale Mode

Brick uses Core Graphics display gamma tables to convert your screen to grayscale:

1. Original color gamma tables are captured for each display
2. Grayscale values are calculated using the luminance formula: `0.299*R + 0.587*G + 0.114*B`
3. The grayscale gamma is applied to all color channels
4. Original gamma tables are restored when you disable grayscale

## Requirements

- macOS 13.0 (Ventura) or later
- Admin privileges (one-time, for website blocking)

## Permissions

- **Admin Authorization**: Required to modify system proxy settings for website blocking
- **No Sandbox**: App runs without sandbox restrictions to access SystemConfiguration framework
- **No Special Entitlements**: Grayscale feature works without additional permissions

## Troubleshooting

### Website blocking isn't working

1. Check System Settings > Network > [Your Connection] > Details > Proxies
2. Verify "Automatic Proxy Configuration" is enabled
3. Verify the PAC URL points to Brick's proxy.pac file
4. Try disabling and re-enabling blocking in Brick

### Grayscale doesn't re-apply after sleep

1. Ensure Brick is still running (check menu bar)
2. Try toggling grayscale off and on again
3. Check Console.app for any error messages from Brick

### Authorization prompt keeps appearing

This shouldn't happen - authorization is requested once and cached. If it persists:
1. Quit Brick completely
2. Delete `~/Library/Application Support/Brick/` directory
3. Relaunch Brick

## Privacy

Brick runs entirely locally on your Mac. No data is collected, transmitted, or shared. All settings are stored locally in macOS UserDefaults.

## Technical Details

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (MenuBarExtra)
- **Build System**: Swift Package Manager
- **APIs Used**:
  - SystemConfiguration (proxy management)
  - CoreGraphics (display gamma)
  - Security (authorization)
  - AppKit (menu bar)

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## Acknowledgments

Built using modern macOS APIs and Swift best practices.
