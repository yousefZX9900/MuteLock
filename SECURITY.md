# Security Policy

## Supported Versions

| Version | Status |
| :------- | :----- |
| **1.1.x** | ✅ **Supported** (Current Stable) |
| 1.0.x | ❌ End of Life |

## Threat Model

MuteLock operates in **Userland** (Ring 3) on the iOS platform. It is designed to protect average users against:
-   **Malicious Apps**: Third-party apps attempting to record in the background or foreground.
-   **Privacy Invasions**: Ads or trackers listening for keywords.

### Out of Scope
MuteLock cannot protect against:
-   **Kernel Exploits**: If an attacker has kernel privileges (Ring 0), they can bypass userland hooks.
-   **Hardware Tampering**: Physical modification of the device.

*For high-threat scenarios, use **Extreme Protection** mode, which terminates the media daemon (`mediaserverd`), reducing the attack surface significantly.*

## Reporting Bugs

If you encounter any issues or bugs:

1.  **Create a GitHub Issue** on the repository.
2.  **Or** Direct Message the developer on Twitter: [@yousef_dev921](https://twitter.com/yousef_dev921)
3.  Please provide details about the issue and how to reproduce it.

We will acknowledge your report and strive to patch it in the next release.

## Disclaimer

This software is provided "as is". While we strive for maximum privacy, no software can guarantee 100% immunity against targeted state-level surveillance.

**Use it at your own risk.**
