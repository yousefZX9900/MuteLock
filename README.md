# MuteLock

A tweak to block camera and microphone access on iOS.

## Features

-  Block camera access
-  Block microphone access  
-  Temporary 5-minute unlock
-  Activity logging
-  Arabic & English support

## How It Works

Two-layer protection system:

| Layer | APIs | Purpose |
|-------|------|---------|
| **A** | AVCaptureDevice, AVCaptureSession, AVAudioSession | App-level blocking |
| **B** | IOKit, AudioUnit, AudioQueue | Low-level blocking |

## Requirements

- iOS 15.0 - 16.5
- Rootless jailbreak (Dopamine tested)

## Installation

1. Download `.deb` from [Releases](https://github.com/yousefZX9900/MuteLock/releases)
2. Install via Sileo, Zebra, or Filza
3. Respring
4. Configure: Settings → MuteLock

## Usage

1. Settings → MuteLock
2. Enable the tweak
3. Toggle camera/microphone blocking
4. Use "Unlock for 5 Minutes" when needed

## Limitations

- Software-level protection (cannot protect against kernel-level access)
- Some apps may crash if they don't handle permission denial gracefully

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Not working | Respring, verify toggles are enabled |
| App crashing | Use temporary unlock for that app |

## Changelog

### v1.0.2
-  Added: AudioQueue hooks for comprehensive mic protection

### v1.0.1
- Initial release

## Contact

- Twitter: [@yousef_dev921](https://twitter.com/yousef_dev921)
- GitHub: [@yousefZX9900](https://github.com/yousefZX9900)

## License

MIT License

---

Made by Yousef
