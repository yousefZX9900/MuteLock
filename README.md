# MuteLock

**Advanced Privacy Shield for iOS (Rootless)**

MuteLock is a powerful privacy tweak designed to give you absolute control over your device's camera and microphone. Unlike standard permissions, MuteLock operates at the system level to intercept and neutralize hardware access.

## Features

- **Smart "Data Zeroing" Protection**: Allows apps to "start" the camera/mic but feeds them black video and silent audio.
  - *Benefit*: Fixes app crashes (e.g., Google Translate) and keeps Flashlight (Torch) functional.
- **Extreme Protection (The Nuclear Option)**:
  - Optional mode that terminates the system media daemon (`mediaserverd`).
  - Provides near-absolute protection for high-threat scenarios.
  - *Note*: Disables all system audio and camera functionality until disabled.
- **Temporary Unlock**: One-tap access to hardware for 5 minutes.
- **Stealth Logging**: Detects and logs silent recording attempts.
- **Full Localization**: Native Arabic and English support.

## How It Works

MuteLock employs a multi-layered defense strategy:

| Layer | Method | Function |
|-------|--------|----------|
| **Layer A** (App) | `AVFoundation` | Neutralizes high-level capture requests. |
| **Layer B** (Data) | `AudioUnit` | Overwrites microphone data buffers with zeros (Digital Silence). |
| **Layer C** (System) | `mediaserverd` | (Optional) Kills the media server entirely. |

## Requirements

- **iOS 15.0 - 16.5+**
- **Rootless Jailbreak** (Dopamine, Palera1n)

## Installation

1. Download the `.deb` file from [Releases](https://github.com/yousefZX9900/MuteLock/releases).
2. Install using **Sileo** or **Filza**.
3. **Respring** your device.
4. Configure via **Settings → MuteLock**.

## Known Limitations

- **Extreme Protection**: When active, this mode intentionally breaks all media functionality. This is a feature, not a bug.
- **Kernel Access**: As a user-mode tweak, it cannot block hardware access if the attacker has a kernel-exploit or hardware modification (though Extreme Protection mitigates most user-mode threats).

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Flashlight not working** | Ensure you are on v1.1.0+ (Data Zeroing fixed this). |
| **App Crash** | Use "Unlock for 5 Minutes" then lock again. |
| **Device Stuck (Respring Loop)** | Force Restart → Enter Safe Mode → Disable Extreme Protection. |

## Disclaimer

This tool is provided for privacy enhancement. While it significantly hardens your device against surveillance, no software solution can guarantee 100% security against state-level actors or kernel exploits. Use it at your own risk.

## Contact

- **Twitter**: [@yousef_dev921](https://twitter.com/yousef_dev921)
- **GitHub**: [@yousefZX9900](https://github.com/yousefZX9900)
- **Donate**: [Buy Me a Coffee](https://buymeacoffee.com/yousefzx9900)

---
*Made with ❤️ by Yousef*
