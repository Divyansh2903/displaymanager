
# Troubleshooting

## Common Issues and Solutions

### App Security Warning: "Apple couldn't verify this app is free of malware"

**Issue**: When trying to open Display Manager for the first time, macOS shows a security warning that says "Apple couldn't verify that 'Display Manager' is free of malware that may harm your Mac" and prevents the app from opening.

**Cause**: This occurs because the Display Manager app is not signed with an Apple Developer Certificate or notarized by Apple. macOS Gatekeeper (Apple's security system) blocks unsigned applications by default to protect users from potential malware.

**Solutions** (try these methods in order):

#### Method 1: Privacy & Security Settings (Recommended)
1. Try to open Display Manager (it will show the security warning)
2. Go to **System Settings** → **Privacy & Security** 
3. Scroll down to the **Security** section
4. Look for a message about Display Manager being blocked
5. Click **"Open Anyway"** next to the blocked app message
6. Enter your administrator password when prompted
7. The app should now open normally

> **Note**: The "Open Anyway" button only appears for about one hour after the security warning is first triggered.

#### Method 2: Right-Click Method (macOS Ventura and earlier)
1. **Right-click** (or Control-click) on the Display Manager app
2. Select **"Open"** from the context menu
3. Click **"Open"** again in the security dialog that appears
4. Enter your administrator password if prompted

> **Important**: This method was removed in macOS Sequoia (15.0+). Use Method 1 instead.

#### Method 3: Remove Quarantine Flag (Advanced Users)
If the above methods don't work, you can remove the quarantine flag using Terminal:

1. Open **Terminal** (Applications → Utilities → Terminal)
2. Type the following command and press Enter:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Display\ Manager.app
   ```
   (Replace the path with the actual location of your Display Manager app)
3. Try opening the app again

#### Method 4: Temporarily Disable Gatekeeper (Not Recommended)
⚠️ **Warning**: This method reduces your Mac's security. Only use if you understand the risks.

**For macOS Sequoia (15.0+):**
1. Open **Terminal**
2. Run: `sudo spctl --global-disable`
3. Go to **System Settings** → **Privacy & Security**
4. Navigate away from Privacy & Security, then back to it
5. Select **"Anywhere"** under "Allow apps downloaded from"
6. Enter your administrator password
7. **Remember to re-enable Gatekeeper** after installing: `sudo spctl --global-enable`

**For macOS Monterey through Ventura:**
1. Open **Terminal**
2. Run: `sudo spctl --master-disable`
3. Go to **System Preferences** → **Security & Privacy** → **General**
4. Select **"Anywhere"** under "Allow apps downloaded from"
5. **Remember to re-enable Gatekeeper** after installing: `sudo spctl --master-enable`

---

### App Won't Start or Crashes

**Issue**: Display Manager opens but immediately crashes or doesn't respond.

**Solutions**:
1. **Check System Requirements**: Ensure you're running macOS 11.0 or later
2. **Restart Your Mac**: Sometimes a simple restart resolves issues
3. **Check Console Logs**: 
   - Open **Console** app (Applications → Utilities)
   - Look for Display Manager related errors
   - Report any errors in the GitHub Issues section

---

### Installation Issues

**Issue**: Problems during installation or first launch.

**Solutions**:
1. **Download from Official Source**: Always download from the official GitHub releases page
2. **Check File Integrity**: Verify the downloaded file isn't corrupted
3. **Clear Downloads**: Remove any previous versions from Downloads folder
4. **Restart After Installation**: Restart your Mac after moving the app to Applications

---

## macOS Version Compatibility

| macOS Version | Gatekeeper Bypass Method | Notes |
|---------------|--------------------------|-------|
| Sequoia (15.0+) | Privacy & Security Settings only | Right-click bypass removed |
| Ventura (13.x) | Privacy & Security Settings or Right-click | Both methods work |
| Monterey (12.x) | Security & Privacy Settings or Right-click | Both methods work |
| Big Sur (11.x) | Security & Privacy Settings or Right-click | Both methods work |

---

## Getting Help

If you're still experiencing issues:

1. **Check Existing Issues**: Search the [GitHub Issues](https://github.com/Divyansh2903/displaymanager/issues) page
2. **Create a New Issue**: Include:
   - macOS version
   - Mac model
---

## Security Note

The security warnings you encounter are normal for applications distributed outside the Mac App Store. Display Manager is open-source, and you can review the code to verify its safety. The app only performs display-related operations and doesn't access sensitive system resources.

For maximum security, consider:
- Reviewing the source code before installation
- Using the Privacy & Security settings method rather than disabling Gatekeeper entirely
