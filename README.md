# iOS Pair

**iOS Pair** is a SwiftUI iPhone app for securely receiving, managing, and exporting iOS pairing files. It includes a glass-inspired interface, a local pairing-file vault, an HTTPS relay client for host-assisted pairing, and a small relay server contract for trusted host agents.

**Creator:** Yanyan  
**Bundle ID:** `com.yanyan.iospair`  
**Minimum deployment target:** iOS 18.0

![iOS Pair app icon](iOSPair/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png)

## What is included

- Native SwiftUI project (`iOSPair.xcodeproj`) with iOS 18 deployment target.
- Liquid Glass card styling on iOS 26 and later, with an Ultra Thin Material fallback on iOS 18–25.
- Pairing-file import from Files and export back to Files.
- Local vault stored in the app container with file protection enabled.
- HTTPS relay client for iOS 18–26. The relay transports a genuine record supplied by a trusted computer-side pairing agent; the relay does not invent Apple credentials.
- Separate client and agent bearer tokens. The iPhone token is stored in Keychain.
- Lightweight Node.js relay reference server in `Server/`.
- Custom app icon in the asset catalog.

## Important pairing behavior and limits

### iOS 18–26

The app can start an HTTPS relay job and receive a pairing file from a trusted host agent. A real pairing record must first be created by a host that is authorized and paired with the iPhone using a supported Apple workflow. The relay is a secure transfer path, not a way to create a pairing relationship with an unpaired phone over the public internet.

The host agent is intentionally a separate component. The reference relay server only queues jobs and transfers the file that the agent submits. It does not perform USB, Wi-Fi, lockdown, or remote-pairing operations itself.

### iOS 27 and later

The app shows the device-side pairing guide and supports importing the resulting `.rppairing` file. The iOS 27 Developer Mode host-advertising integration is **not implemented** in this starter source. Apple requires the user to approve the Developer Mode flow; this project does not send fake system notifications, toggle Developer Mode, or fabricate a pairing record.

Apple's public `DeviceDiscoveryUI` framework provides peer-to-peer pairing between apps and accessories. Its public documentation does not describe it as an API for creating a Developer Mode pairing host or exporting the system pairing credential. See `docs/IOS27-NATIVE-PAIRING.md`.

## Compatibility

| Item | Support |
|---|---|
| Device family | iPhone (universal iOS app target) |
| Deployment target | iOS 18.0+ |
| iOS 18 | Import/export and HTTPS relay transfer; relay requires a trusted host agent |
| iOS 26 | Same relay/import/export path, plus Liquid Glass card styling |
| iOS 27+ | Guided device-side workflow and file import; native Developer Mode host integration is not included |
| iPad | Not targeted or validated in this project |

Actual device compatibility depends on whether Apple supports the installed iOS release on that iPhone model. This project does not make older devices compatible with newer iOS releases.

## Build in Xcode

1. Open `iOSPair.xcodeproj` in Xcode 27 or a compatible Xcode release that includes the iOS 26/27 SDKs.
2. Select the `iOSPair` target.
3. In **Signing & Capabilities**, choose your own development team and a unique bundle identifier if needed.
4. Select an iPhone running iOS 18 or later, then Build and Run.

No third-party Swift packages are required.

## Configure the HTTPS relay

1. Deploy `Server/relay-server.mjs` behind an HTTPS reverse proxy. The Node process binds to loopback by default.
2. Set different long random values for `IOSPAIR_CLIENT_TOKEN` and `IOSPAIR_AGENT_TOKEN`.
3. Enter the HTTPS base URL and the **client** token in iOS Pair → Relay settings.
4. Run a trusted host agent that completes the user's pairing through a supported workflow and submits the resulting genuine pairing record to `POST /v1/agent/jobs/{id}/complete` with the **agent** token.

See `Server/README.md` for the exact API contract. The reference server keeps jobs in memory for 15 minutes and is intended as a starting point, not a production service.

## Pairing file handling

The app accepts `.plist`, `.rppairing`, `.pairing`, `.mobiledevicepairing`, and `.json` files up to 15 MB. It checks that the file parses as a plist or JSON container. **This is syntax validation only**; it does not prove that the file is a genuine, current, or usable Apple pairing record.

Pairing records can contain sensitive device credentials. Keep exports private, use HTTPS, protect relay tokens, and delete files you no longer need. The app does not upload imported files except when you explicitly use the relay flow.

## Repository layout

```text
.
├── iOSPair.xcodeproj/
├── iOSPair/
│   ├── App/
│   ├── Core/
│   ├── Views/
│   └── Resources/Assets.xcassets/
├── Server/
│   ├── relay-server.mjs
│   └── README.md
├── docs/
│   └── IOS27-NATIVE-PAIRING.md
├── LICENSE
└── README.md
```

## References

- Apple Developer — [Enabling Developer Mode on a device](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
- Apple Developer — [DeviceDiscoveryUI](https://developer.apple.com/documentation/devicediscoveryui/)
- Apple Developer — [iOS & iPadOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)
- Pairing workflow background — [idevice_pair README](https://github.com/jkcoxson/idevice_pair)

## License

MIT. See [`LICENSE`](LICENSE).
