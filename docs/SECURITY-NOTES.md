# Security notes

- Pairing records may contain device-bound credentials. Treat them like passwords.
- iOS Pair stores imported files in its app container with iOS file protection. Exports are user-initiated.
- The relay requires HTTPS and separate client/agent bearer tokens. Configure TLS at the reverse proxy; the reference Node server intentionally binds to loopback.
- The reference server stores data in memory only and expires jobs after 15 minutes. It is a protocol example, not production infrastructure.
- The app's parser checks plist/JSON structure only. It does not cryptographically authenticate Apple pairing records.
- The iOS 27 Developer Mode path is deliberately user-controlled. The app cannot enable Developer Mode, restart the phone, type a passcode, accept system prompts, or claim a pairing is complete without the system's actual result.
