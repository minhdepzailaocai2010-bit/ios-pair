import Foundation
import UniformTypeIdentifiers

struct PairingRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let fileName: String
    let storedName: String
    let createdAt: Date
    let byteCount: Int
    let format: String
    let source: String

    init(fileName: String, storedName: String, byteCount: Int, format: String, source: String) {
        self.id = UUID()
        self.fileName = fileName
        self.storedName = storedName
        self.createdAt = .now
        self.byteCount = byteCount
        self.format = format
        self.source = source
    }
}

enum PairingFileError: LocalizedError {
    case empty
    case tooLarge
    case unsupportedFormat
    case invalidContainer
    case missingRecord
    case missingFile

    var errorDescription: String? {
        switch self {
        case .empty: return "The selected file is empty."
        case .tooLarge: return "The file exceeds the 15 MB safety limit."
        case .unsupportedFormat: return "Choose a .plist, .rppairing, .pairing, .mobiledevicepairing, or .json file."
        case .invalidContainer: return "The file is not a valid plist or JSON container."
        case .missingRecord: return "The saved pairing file could not be found."
        case .missingFile: return "The selected file is no longer available."
        }
    }
}

struct PairingFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .propertyList, .json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw PairingFileError.invalidContainer
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
