import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @EnvironmentObject private var vault: PairingVault
    @AppStorage("relayURL") private var relayURL = "https://relay.example.com"
    @State private var relayToken = ""
    @State private var isPairing = false
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument: PairingFileDocument?
    @State private var exportName = "ios-pairing.rppairing"
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var showNativeInfo = false
    @State private var showSettings = false

    private let relay = PairingRelayClient()
    private let keychain = KeychainTokenStore()

    private var majorOSVersion: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }
    private var isIOS27OrLater: Bool { majorOSVersion >= 27 }
    private var osLabel: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "iOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    var body: some View {
        ZStack {
            ambientBackground
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    statusStrip
                    workflowCard
                    actionRow
                    if !isIOS27OrLater { relaySettingsCard }
                    recordsSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            relayToken = keychain.read() ?? ""
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.data, .propertyList, .json],
            allowsMultipleSelection: false,
            onCompletion: importResult
        )
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .data,
            defaultFilename: exportName,
            onCompletion: exportResult
        )
        .alert("Pairing status", isPresented: Binding(
            get: { message != nil || errorMessage != nil },
            set: { if !$0 { message = nil; errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { message = nil; errorMessage = nil }
        } message: {
            Text(errorMessage ?? message ?? "")
        }
        .sheet(isPresented: $showNativeInfo) { nativePairingGuide }
        .sheet(isPresented: $showSettings) { relaySettingsSheet }
    }

    private var ambientBackground: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.018, green: 0.035, blue: 0.12), Color(red: 0.025, green: 0.055, blue: 0.19), Color(red: 0.055, green: 0.025, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color.cyan.opacity(0.15)).frame(width: 260).blur(radius: 85).offset(x: 150, y: -260)
            Circle().fill(Color.blue.opacity(0.18)).frame(width: 300).blur(radius: 90).offset(x: -150, y: 80)
            Circle().fill(Color.purple.opacity(0.12)).frame(width: 220).blur(radius: 90).offset(x: 140, y: 460)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("AppMark")
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.24), lineWidth: 1))
                .shadow(color: .cyan.opacity(0.25), radius: 18, y: 5)
            VStack(alignment: .leading, spacing: 3) {
                Text("iOS Pair")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                Text("PAIRING CONTROL CENTER  /  YANYAN")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(.cyan.opacity(0.82))
            }
            Spacer()
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(.cyan)
                .symbolEffect(.pulse, isActive: isPairing)
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            Circle().fill(isPairing ? .orange : .green).frame(width: 7, height: 7)
            Text(isPairing ? "PAIRING SESSION ACTIVE" : "SYSTEM READY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.1)
            Spacer()
            Text(osLabel.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.white.opacity(0.055), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
    }

    private var workflowCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(isIOS27OrLater ? "ON-DEVICE ROUTE" : "SECURE RELAY ROUTE", systemImage: isIOS27OrLater ? "iphone.gen3.radiowaves.left.and.right" : "globe.americas.fill")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(.cyan)
                    Spacer()
                    Text(isIOS27OrLater ? "27+" : "18—26")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.cyan.opacity(0.13), in: Capsule())
                }
                Text(isIOS27OrLater ? "Device-side pairing" : "Pair through a trusted host")
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                Text(isIOS27OrLater
                     ? "iOS can present a system-managed host selection flow. The native Developer Mode host adapter is a separate integration and is not enabled in this starter build."
                     : "Create a pairing job over HTTPS. A trusted computer-side pairing agent completes the system pairing and returns the real record to this iPhone.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                    Text(isIOS27OrLater ? "System approval stays in your hands" : "HTTPS only · token stored in Keychain")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    private var actionRow: some View {
        VStack(spacing: 11) {
            Button {
                if isIOS27OrLater { showNativeInfo = true }
                else { Task { await startRelayPairing() } }
            } label: {
                HStack(spacing: 10) {
                    if isPairing { ProgressView().tint(.white) }
                    else { Image(systemName: isIOS27OrLater ? "iphone.badge.play" : "bolt.horizontal.circle.fill").font(.system(size: 18, weight: .semibold)) }
                    Text(isPairing ? "WORKING…" : (isIOS27OrLater ? "PREPARE DEVICE PAIRING" : "START SECURE PAIRING"))
                        .font(.system(size: 13, weight: .bold, design: .rounded)).tracking(0.6)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.01, green: 0.06, blue: 0.15))
                .padding(.horizontal, 19).frame(height: 58)
                .background(LinearGradient(colors: [Color.cyan, Color(red: 0.35, green: 0.72, blue: 1)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .cyan.opacity(0.25), radius: 20, y: 8)
            }
            .disabled(isPairing)

            HStack(spacing: 10) {
                Button { showImporter = true } label: {
                    Label("Import file", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.11), lineWidth: 1))
                }
                Button { showSettings = true } label: {
                    Label("Relay settings", systemImage: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.11), lineWidth: 1))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.88))
        }
    }

    private var relaySettingsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("RELAY CONFIGURATION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
                        .foregroundStyle(.cyan)
                    Spacer()
                    Button("EDIT") { showSettings = true }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                Text(relayURL)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                Text(relayToken.isEmpty ? "No access token saved" : "Access token secured in Keychain")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PAIRING VAULT").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(.cyan)
                    Text("Saved records").font(.system(size: 21, weight: .semibold, design: .rounded))
                }
                Spacer()
                Text(String(format: "%02d FILES", vault.records.count))
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.52))
            }
            if vault.records.isEmpty {
                GlassCard {
                    VStack(spacing: 9) {
                        Image(systemName: "externaldrive.badge.questionmark").font(.system(size: 28, weight: .light)).foregroundStyle(.cyan.opacity(0.8))
                        Text("Vault is empty").font(.system(size: 14, weight: .semibold))
                        Text("Import a pairing record or complete a relay job to see it here.")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.56)).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                }
            } else {
                ForEach(vault.records) { record in recordRow(record) }
            }
        }
    }

    private func recordRow(_ record: PairingRecord) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "doc.zipper")
                    .font(.system(size: 22)).foregroundStyle(.cyan)
                    .frame(width: 42, height: 42)
                    .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.fileName).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text("\(record.format.uppercased()) · \(ByteCountFormatter.string(fromByteCount: Int64(record.byteCount), countStyle: .file)) · \(record.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.5)).lineLimit(2)
                }
                Spacer(minLength: 4)
                Menu {
                    Button { prepareExport(record) } label: { Label("Export to Files", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) { vault.delete(record) } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle.fill").font(.system(size: 22)).foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 5) {
            Text("LOCAL-FIRST STORAGE  ·  NO ANALYTICS")
                .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
                .foregroundStyle(.white.opacity(0.42))
            Text("Created by Yanyan")
                .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity).padding(.top, 2)
    }

    private var nativePairingGuide: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Label("iOS 27+ device-side pairing", systemImage: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Text("This source package does not include the private/native Developer Mode host adapter. It will not send a fake system notification or manufacture a pairing credential.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                guideStep("01", "Enable Developer Mode", "Settings → Privacy & Security → Developer Mode. Follow the restart and confirmation prompts shown by iOS.")
                guideStep("02", "Use a compatible pairing host", "A supported iOS 27 pairing-host implementation must advertise itself to the system. Select that host in the Developer Mode pairing screen and approve the prompts yourself.")
                guideStep("03", "Import the resulting record", "Return to iOS Pair and use Import file to store the exported .rppairing file in the local vault.")
                Spacer()
                Button("Import pairing file") { showNativeInfo = false; showImporter = true }
                    .buttonStyle(.borderedProminent).tint(.cyan).frame(maxWidth: .infinity)
            }
            .padding(22)
            .navigationTitle("On-device flow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showNativeInfo = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func guideStep(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.cyan)
                .padding(9).background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private var relaySettingsSheet: some View {
        NavigationStack {
            Form {
                Section("HTTPS pairing relay") {
                    TextField("https://relay.example.com", text: $relayURL)
                        .textInputAutocapitalization(.never).keyboardType(.URL).autocorrectionDisabled()
                    SecureField("Bearer token", text: $relayToken)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Text("The relay transfers a record created by your trusted pairing host. It does not create Apple credentials on its own. HTTPS is required.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("Save securely") {
                        keychain.save(relayToken)
                        showSettings = false
                        message = "Relay settings saved."
                    }
                    .disabled(relayURL.trimmingCharacters(in: .whitespaces).isEmpty || relayToken.isEmpty)
                }
            }
            .navigationTitle("Relay settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSettings = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func startRelayPairing() async {
        guard !relayToken.isEmpty else {
            errorMessage = "Add your HTTPS relay URL and bearer token in Relay settings first."
            return
        }
        isPairing = true
        defer { isPairing = false }
        do {
            let model = UIDevice.current.model
            let (data, fileName) = try await relay.requestPairingFile(
                baseURL: relayURL,
                token: relayToken,
                osVersion: osLabel,
                deviceModel: model
            )
            _ = try vault.importFile(data: data, fileName: fileName, source: "HTTPS relay")
            message = "The relay returned a structured pairing file and it was saved to the local vault. Syntax validation is not cryptographic validation."
        } catch is CancellationError {
            message = "Pairing request cancelled."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importResult(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            _ = try vault.importFile(data: data, fileName: url.lastPathComponent, source: "Files import")
            message = "Pairing file imported. Its container was parsed; the record has not been cryptographically tested."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareExport(_ record: PairingRecord) {
        do {
            exportDocument = PairingFileDocument(data: try vault.data(for: record))
            exportName = record.fileName
            showExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success: message = "Pairing file exported. Keep it private; it may contain device credentials."
        case .failure(let error): errorMessage = error.localizedDescription
        }
        exportDocument = nil
    }
}
