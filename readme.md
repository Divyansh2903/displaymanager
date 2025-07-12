# Display Manager

A macOS menu bar application for managing and switching between multiple display configurations with ease.

![macOS](https://img.shields.io/badge/macOS-11.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0+-green.svg)

## Overview

Display Manager is a lightweight macOS application that sits in your menu bar and allows you to:
- Save your current display arrangement as named profiles
- Quickly switch between different display configurations
- Preview display arrangements before applying them
- Manage multiple monitor setups with ease

Perfect for users who frequently switch between different display configurations, work in multiple locations, or need to quickly adapt their setup for presentations.

## Features

### Core Functionality
- **Save Current Setup**: Capture your current display configuration as a named profile
- **Apply Profiles**: Switch between saved display configurations with a single click
- **Visual Preview**: See a visual representation of your display arrangement before applying
- **Menu Bar Integration**: Quick access from the macOS menu bar
- **Profile Management**: Rename, delete, and organize your saved configurations

### Data Management
- JSON-based storage
- Profile metadata including display count and configuration details

## Requirements

- macOS 11.0 (Big Sur) or later with M-series chips
- Multiple displays (for meaningful use)
- `displayplacer` binary (included with the app)

## Installation

### Option 1: Build from Source

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/display-manager.git
   cd display-manager
   ```

2. Open the project in Xcode:
   ```bash
   open DisplayManager.xcodeproj
   ```

3.  Build and run:
   -  The displayplacer binary is already included in the project bundle
   -  No additional dependencies need to be installed
   -  Simply build and run the project in Xcode (⌘+R)

### Option 2: Pre-built Binary

1. Download the latest release from the [Releases](https://github.com/Divyansh2903/displaymanager/releases) page
2. If you encounter the "Apple couldn't verify Display Manager is free of malware" error, Go to **System Settings** → **Privacy & Security** → Click **"Open Anyway"**
3. Move the app to your Applications folder
4. Launch Display Manager

## Usage

### Getting Started

1. **Launch the app**: Display Manager will appear in your menu bar with a display icon
2. **Save your first profile**:
   - Click the menu bar icon
   - Click "Save Current Setup"
   - Enter a name for your profile (e.g., "Work Setup", "Gaming Config")
   - Click "Save"

### Managing Profiles

#### Applying Profiles
- Click the menu bar icon to open the interface
- Click the blue play button next to any profile to apply it
- The currently applied profile will show a green checkmark

#### Previewing Arrangements
- Click the eye icon next to any profile to see a visual preview
- The preview shows the relative position and size of each display
- Display names and numbers are shown for easy identification

#### Deleting Profiles
- Click the red trash icon next to any profile
- Confirm deletion in the dialog that appears
- Note: This action cannot be undone

### Tips for Best Results

1. **Create profiles for different scenarios**:
   - Work setup (multiple external monitors)
   - Laptop only (mobile work)
   - Presentation mode (mirrored displays)
   - Gaming setup (primary display only)

2. **Use descriptive names**: Instead of "Profile 1", use "Work - Dual Monitor" or "Home - TV Setup"

3. **Test profiles**: Always preview before applying to ensure the configuration is correct

## Technical Details

### Architecture

The application is built using modern Swift and SwiftUI technologies:

- **SwiftUI**: For the user interface
- **AppKit**: For menu bar integration and system-level functionality
- **CoreGraphics**: For display geometry calculations
- **Combine**: For reactive programming patterns

### Display Detection

The app uses the `displayplacer` from [jakehilborn/displayplacer] utility to:
- Detect current display configuration
- Parse display properties (resolution, position, rotation)
- Apply new configurations
- Handle display identification and mapping

### Profile Structure

Each profile contains:
- Unique identifier (UUID)
- User-friendly name
- Display configuration arguments
- Full output from displayplacer for metadata

## Troubleshooting

### Common Issues

**App does not start**
- If you encounter the "Apple couldn't verify Display Manager is free of malware" error, this is a normal macOS security feature. See our [complete troubleshooting guide](./troubleshoot.md) for step-by-step solutions.

**Quick fix:**
- Go to **System Settings** → **Privacy & Security** → Click **"Open Anyway"**
- Right-click the app and select **"Open"** (macOS Ventura and earlier)

**App doesn't appear in menu bar**
- Check that the app is running (look in Activity Monitor)
- Try restarting the app
- Ensure macOS version compatibility

**Profile application fails**
- Verify all displays are connected and powered on
- Check that display configuration is valid
- Try saving a new profile with current setup

**Displays not detected correctly**
- Check System Preferences > Security & Privacy for permissions
- Restart the app after connecting/disconnecting displays

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

1. Clone the repository
2. Open in Xcode 13 or later
3. Ensure you have the latest Swift toolchain

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [displayplacer](https://github.com/jakehilborn/displayplacer) - The underlying utility that makes this app possible

## Support

If you encounter issues or have feature requests:
1. Check the [Issues](https://github.com/Divyansh2903/displaymanager/issues) page
2. Create a new issue with detailed information
3. Include your macOS version and display configuration

---

**Note**: This app is not affiliated with Apple Inc. macOS is a trademark of Apple Inc.
