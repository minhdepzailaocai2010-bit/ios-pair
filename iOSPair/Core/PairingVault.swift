import Foundation
import Combine

@MainActor
final class PairingVault: ObservableObject {
    @Published private(set) var records: [PairingRecord] = []

    private let fileManager = FileManager.default
    private let metadataName = "records.json"

    private var rootURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("IOSPair", isDirectory: true)
    }

    private var recordsURL: URL { rootURL.appendingPathComponent(metadataName) }

    init() { loadIndex() }

    func importFile(data: Data, fileName: String, source: String) throws -> PairingRecord {
        guard !data.isEmpty else { throw PairingFileError.empty }
        guard data.count <= 15 * 1_024 * 1_024 else { throw PairingFileError.tooLarge }
        guard Self.isAllowedExtension(fileName) else { throw PairingFileError.unsupportedFormat }
        guard Self.isStructuredContainer(data, fileName: fileName) else {
            throw PairingFileError.invalidContainer
        }

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let sanitized = Self.safeFileName(fileName)
        let storedName = "\(UUID().uuidString)-\(sanitized)"
        let destination = rootURL.appendingPathComponent(storedName)
        try data.write(to: destination, options: [.atomic, .completeFileProtection])

        let record = PairingRecord(
            fileName: sanitized,
            storedName: storedName,
            byteCount: data.count,
            format: URL(fileURLWithPath: sanitized).pathExtension.lowercased(),
            source: source
        )
        records.insert(record, at: 0)
        saveIndex()
        return record
    }

    func data(for record: PairingRecord) throws -> Data {
        let url = rootURL.appendingPathComponent(record.storedName)
        guard fileManager.fileExists(atPath: url.path) else { throw PairingFileError.missingFile }
        return try Data(contentsOf: url)
    }

    func delete(_ record: PairingRecord) {
        let url = rootURL.appendingPathComponent(record.storedName)
        try? fileManager.removeItem(at: url)
        records.removeAll { $0.id == record.id }
        saveIndex()
    }

    static func isAllowedExtension(_ name: String) -> Bool {
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
        return ["plist", "rppairing", "pairing", "mobiledevicepairing", "json"].contains(ext)
    }

    /// Checks syntax/container shape only. It does NOT cryptographically validate an Apple pairing record.
    static func isStructuredContainer(_ data: Data, fileName: String) -> Bool {
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        if ext == "json" {
            return (try? JSONSerialization.jsonObject(with: data)) != nil
        }
        if (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) != nil {
            return true
        }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private static func safeFileName(_ raw: String) -> String {
        let leaf = URL(fileURLWithPath: raw).lastPathComponent
        let filtered = leaf.unicodeScalars.filter {
            CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ._-()")).contains($0)
        }
        let value = String(String.UnicodeScalarView(filtered)).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "pairing-record.plist" : value
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: recordsURL),
              let decoded = try? JSONDecoder().decode([PairingRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded.filter { fileManager.fileExists(atPath: rootURL.appendingPathComponent($0.storedName).path) }
    }

    private func saveIndex() {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(records)
            try data.write(to: recordsURL, options: [.atomic, .completeFileProtection])
        } catch {
            assertionFailure("Unable to persist pairing index: \(error.localizedDescription)")
        }
    }
}
