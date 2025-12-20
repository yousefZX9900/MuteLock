# Security Policy

## Supported Versions

| Version | iOS Support | Status |
| ------- | ----------- | ------ |
| 1.0.x   | 15.0 - 16.5 | ✅ Supported |

## Reporting a Vulnerability

If you discover a security vulnerability in MuteLock, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Send a direct message to [@yousef_dev921](https://twitter.com/yousef_dev921) on Twitter
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes

I will respond within 48 hours and work with you to address the issue.

## Security Model

MuteLock provides **software-level protection** against camera and microphone access. Please understand the following:

### What MuteLock Protects Against

- ✅ Apps silently accessing camera/microphone
- ✅ Background recording attempts
- ✅ Automated/programmatic access via AVFoundation APIs
- ✅ Low-level IOKit camera access
- ✅ AudioUnit raw audio capture

### Limitations

- ⚠️ Root-level attacks by other tweaks with same or higher privilege
- ⚠️ Kernel-level exploits
- ⚠️ Physical access attacks
- ⚠️ Hardware implants

## Best Practices

For maximum security:

1. Keep MuteLock updated
2. Use only trusted jailbreak tools
3. Be cautious with other tweaks that request camera/mic access
4. Regularly check the activity logs
5. Report any suspicious behavior

## Acknowledgments

Security researchers who responsibly disclose vulnerabilities will be acknowledged here (with permission).
