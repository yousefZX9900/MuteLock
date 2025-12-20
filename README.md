# MuteLock

Advanced Camera & Microphone Protection for iOS

## Overview

MuteLock is a powerful iOS tweak that provides multi-layer protection for your camera and microphone against unauthorized access. It uses advanced hooking techniques at two different system levels to ensure comprehensive protection.

## Features

### Multi-Layer Protection
- Layer A (AVFoundation): Hooks high-level APIs for camera and microphone access
- Layer C (IOKit + AudioUnit): Low-level hardware access and audio input protection

### Modern User Interface
- Clean, modern design with iOS 15+ support
- Real-time status indicators
- Color-coded feedback for different states
- Support for both Arabic and English languages

### Temporary Unlock
- Quick 5-minute temporary unlock feature
- Automatic re-lock after expiry
- One-tap emergency access

### Activity Logging
- Track all blocked access attempts
- View app names and timestamps
- Clear logs when needed

## Installation

### Requirements
- iOS 15.0 - 16.5
- Jailbroken device (Dopamine, Palera1n rootless supported)
- Cydia Substrate, Substitute, libhooker, or ElleKit

### Steps
1. Download the `.deb` file from [Releases](https://github.com/yousefZX9900/MuteLock/releases)
2. Install using your preferred package manager (Sileo, Zebra, etc.)
3. Respring your device
4. Configure MuteLock in Settings

## Usage

### Basic Setup
1. Open Settings -> MuteLock
2. Enable MuteLock toggle
3. Select what to protect:
   - Lock Camera
   - Lock Microphone
   - Or both

### Temporary Unlock
- When you need temporary access, tap "Unlock for 5 Minutes"
- All protection will be disabled for 5 minutes
- Automatic re-lock after time expires
- Tap "Lock Now" to re-enable protection immediately

## Technical Details

### Architecture
```
User Application
       ↓
Layer A: AVFoundation Hooks
(AVCaptureDevice, AVCaptureSession, AVAudioSession, UIImagePickerController)
       ↓
Layer C: Low-Level Hooks
(IOKit - IOServiceOpen, AudioUnit - AudioUnitRender/AudioOutputUnitStart)
       ↓
Camera/Microphone Hardware
```

### Hook Points
- `AVCaptureDevice` authorization methods
- `AVCaptureSession` input management
- `AVAudioSession` record permissions
- `UIImagePickerController` camera access
- `IOServiceOpen` for hardware-level camera blocking
- `AudioUnitRender` / `AudioOutputUnitStart` for raw audio interception

### Files and Locations
- Preferences: `/var/jb/var/mobile/Library/Preferences/com.mutelock.settings.plist`
- Logs: `/var/jb/var/mobile/Library/Preferences/com.mutelock.log.plist`
- Bundle: `/var/jb/Library/PreferenceBundles/MuteLockPrefs.bundle`

## Important Notes

- This is software-level protection designed to prevent automated/silent access
- Sophisticated attackers with system-level access may bypass these protections
- MuteLock works best on rootless jailbreaks (Dopamine 2.0+, Palera1n)
- Always keep your device updated and use trusted sources

## Troubleshooting

### Protection Not Working?
1. Ensure you have resprung after installation
2. Check that MuteLock is enabled
3. Verify global protection switches are ON

### Apps Crashing?
- Some apps may not handle permission denial gracefully
- Use the Temporary Unlock feature if you need to use the app
- Report persistent issues on GitHub

### Temporary Unlock Not Working?
- Check system time/date settings
- Disable and re-enable the feature
- Respring if needed

## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests
- Improve documentation

## Contact and Support

- Developer: Yousef
- Twitter: [@yousef_dev921](https://twitter.com/yousef_dev921)
- GitHub: [@yousefZX9900](https://github.com/yousefZX9900)
- Support: [Buy Me a Coffee](https://buymeacoffee.com/yousefzx9900)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Thanks to the jailbreak community for their continued support
- Special thanks to all beta testers
- Inspired by privacy-focused security tools

---

Made by Yousef

If you find this project useful, consider supporting my work at https://buymeacoffee.com/yousefzx9900
