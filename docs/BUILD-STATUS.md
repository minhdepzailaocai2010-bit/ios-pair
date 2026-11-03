# Build status

- Swift source files were syntax-parsed with the Swift frontend.
- The Xcode project property-list syntax was checked with `plutil`.
- The Node relay was smoke-tested through job creation, agent claim, upload, and client download.
- A full iOS compile/sign/install was not run in this environment because Xcode and an iOS SDK/device are not available here. Open the project in Xcode on macOS and select a signing team before building.
