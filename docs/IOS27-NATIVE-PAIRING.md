# iOS 27 native pairing integration boundary

The iOS Pair project deliberately does not pretend that a normal iOS app can call a public Apple API to make the Developer Mode system prompt appear or to read the resulting system pairing credential. Apple's public Developer Mode instructions describe the approval and restart flow, but do not document a third-party app API for generating the system pairing record.

Apple's `DeviceDiscoveryUI` framework is public and supports secure peer-to-peer pairing between apps and accessories. It is **not** documented as an API for creating the Developer Mode host or exporting Apple's Developer Mode pairing record.

The UI therefore provides a user-guided route on iOS 27+: enable Developer Mode yourself, pair with a compatible host that the system recognizes, then import the resulting `.rppairing` file. A future provider can be added behind a dedicated adapter once a documented Apple API or a separately reviewed provider implementation is available.

Do not replace this boundary with a fabricated plist, a spoofed Settings notification, or a credential copied from another device. Those files are not valid pairing records and can expose device credentials.
