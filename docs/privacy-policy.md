---
layout: page
title: Privacy Policy
permalink: /privacy-policy
---

# Privacy Policy

**Shinobi Term**
Last updated: 2025-06-01

## Overview

Shinobi Term is an open-source SSH terminal client for iOS. Your privacy is important to us. This policy explains what data we collect and how we handle it.

## Data Collection

**We do not collect any personal data.**

Shinobi Term does not use analytics, crash reporting, advertising SDKs, or any third-party tracking services.

## Data Storage

All data is stored locally on your device:

- **Connection profiles** (hostname, port, username) are stored in the app's local database using SwiftData.
- **Passwords** are stored in the iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` protection.
- **SSH private keys** are generated on-device using Apple CryptoKit (Ed25519) and stored exclusively in the iOS Keychain. Private keys never leave your device.
- **App settings** (font, scrollback buffer size, etc.) are stored locally.

No data is transmitted to our servers or any third party. All network communication is initiated by you when connecting to your own SSH servers.

## Network Communication

Shinobi Term connects only to SSH servers that you explicitly configure. All connections use the SSH protocol (encrypted). We do not operate any relay servers or intermediary services.

## In-App Purchases

Shinobi Term offers an optional tip jar via Apple's In-App Purchase system. Purchase transactions are handled entirely by Apple. We do not receive or store any payment information.

## Third-Party Services

Shinobi Term does not integrate with any third-party services. The app is fully self-contained.

## Children's Privacy

Shinobi Term is a developer tool and is not directed at children under 13.

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be posted to this page and reflected in the app's settings.

## Contact

If you have questions about this privacy policy, please open an issue on our GitHub repository:

https://github.com/IE3/shinobi-term/issues

---

IE3 LLC.
