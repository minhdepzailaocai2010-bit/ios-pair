import SwiftUI

@main
struct IOSPairApp: App {
    @StateObject private var vault = PairingVault()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vault)
                .preferredColorScheme(.dark)
        }
    }
}
