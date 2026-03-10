# AMAPP - Adaptive Music Application

Organize, render, and implement adaptive music for games — directly inside REAPER.

## Features

- **Render Clusters** — group regions and items for batch rendering with wildcards, naming conventions, and format options
- **Timeline Overlay** — visual cluster management directly on the REAPER arrange view
- **Cluster Hierarchy** — organize clusters into groups and sets that map to game audio structures
- **Wwise / WAXML Integration** — export directly to Wwise or generate WAXML files for middleware import
- **Implementation Design** — plan and export your adaptive music architecture for game engines
- **Fixed Lanes** — create, duplicate, and render clusters from REAPER's fixed lanes
- **11 Action Scripts** — bind common operations to hotkeys

## Requirements

| Dependency | Install via |
|-----------|-------------|
| [SWS/S&M Extension](https://www.sws-extension.org/) | Manual |
| [ReaImGui](https://forum.cockos.com/showthread.php?t=250419) | ReaPack |
| [js_ReaScriptAPI](https://forum.cockos.com/showthread.php?t=212174) | ReaPack |

## Install via ReaPack

1. In REAPER: `Extensions > ReaPack > Import repositories...`
2. Paste this URL:
   ```
   https://raw.githubusercontent.com/Mount-West-Music/AMAPP/main/index.xml
   ```
3. `Extensions > ReaPack > Browse packages` — search for "AMAPP" and install
4. Restart REAPER

## C++ Extension (Optional, Recommended)

For best performance, install the AMAPP C++ extension:

| Platform | File | Architecture |
|----------|------|-------------|
| macOS | `reaper_amapp.dylib` | Universal (Intel + Apple Silicon) |
| Windows | `reaper_amapp.dll` | 64-bit (requires 64-bit REAPER) |

1. Download the latest release for your platform from [Releases](https://github.com/Mount-West-Music/AMAPP/releases)
2. Copy the file to your REAPER `UserPlugins` folder:
   - macOS: `~/Library/Application Support/REAPER/UserPlugins/`
   - Windows: `%APPDATA%\REAPER\UserPlugins\`
3. Restart REAPER

AMAPP works without the extension, but some operations will be slower. Linux is not currently supported.

## Wwise Setup (Optional)

1. Open Wwise with your project
2. Enable WAAPI: `Project > User Preferences > Enable Wwise Authoring API`
3. Use AMAPP's "Implementation Design" to export your adaptive music structure

## License

AMAPP is proprietary commercial software by Mount West Music AB.
Licensed users receive full access to all features.

## Support

- Discord: https://discord.gg/xs8AEhx6h2
- Email: support@mountwestmusic.com
- Website: https://amapp.io
