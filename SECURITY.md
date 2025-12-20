# Security Policy

## Supported Versions

| Version | iOS Support | Status |
|---------|-------------|--------|
| 1.0.x   | 15.0 - 16.5 | Active |

## Protection Scope

MuteLock blocks camera and microphone access through:
- **App-level hooks** (AVFoundation APIs)
- **Low-level hooks** (IOKit, AudioUnit, AudioQueue)

### What It Protects Against
- Standard app camera/microphone access
- Most tweaks attempting to access sensors
- Background recording attempts

### Out of Scope
- Kernel-level exploits
- Physical device access
- Tweaks with higher injection priority

## Reporting Security Issues

If you discover a bypass or security issue:

1. **GitHub Issues**: [Open an issue](https://github.com/yousefZX9900/MuteLock/issues)
2. **Twitter DM**: [@yousef_dev921](https://twitter.com/yousef_dev921)

Please include:
- iOS version and device model
- Steps to reproduce the bypass
- Any relevant logs

## Best Practices

- Keep the tweak updated
- Enable both camera and mic protection for maximum coverage
- Use temporary unlock only when necessary

