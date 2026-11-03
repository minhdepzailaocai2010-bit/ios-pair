import Foundation

struct RelayJobResponse: Decodable {
    let id: String
    let status: String
    let message: String?
}

struct RelayResultResponse: Decodable {
    let id: String
    let status: String
    let fileName: String?
    let mimeType: String?
    let fileBase64: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case id, status, message
        case fileName = "file_name"
        case mimeType = "mime_type"
        case fileBase64 = "file_base64"
    }
}

enum RelayError: LocalizedError {
    case invalidEndpoint
    case insecureTransport
    case invalidResponse
    case jobFailed(String)
    case timedOut
    case missingPayload

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "Enter a valid relay URL."
        case .insecureTransport: return "The relay must use HTTPS."
        case .invalidResponse: return "The relay returned an invalid response."
        case .jobFailed(let message): return message
        case .timedOut: return "The pairing host did not finish before the timeout."
        case .missingPayload: return "The relay finished without a pairing-file payload."
        }
    }
}

struct PairingRelayClient {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) { self.session = session }

    func requestPairingFile(baseURL: String, token: String, osVersion: String, deviceModel: String) async throws -> (Data, String) {
        guard let root = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = root.scheme?.lowercased(),
              let host = root.host, !host.isEmpty else { throw RelayError.invalidEndpoint }
        guard scheme == "https" else { throw RelayError.insecureTransport }

        let createURL = root.appendingPathComponent("v1").appendingPathComponent("jobs")
        var create = URLRequest(url: createURL)
        create.httpMethod = "POST"
        create.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        create.setValue("application/json", forHTTPHeaderField: "Content-Type")
        create.timeoutInterval = 20
        create.httpBody = try encoder.encode(CreateJobBody(osVersion: osVersion, deviceModel: deviceModel, requestedFormat: "RPPairing"))

        let (createData, createResponse) = try await session.data(for: create)
        try Self.checkHTTP(createResponse)
        guard let response = try? decoder.decode(RelayJobResponse.self, from: createData) else { throw RelayError.invalidResponse }
        let jobID = response.id

        for _ in 0..<90 {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let statusURL = root.appendingPathComponent("v1").appendingPathComponent("jobs").appendingPathComponent(jobID)
            var statusRequest = URLRequest(url: statusURL)
            statusRequest.httpMethod = "GET"
            statusRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            statusRequest.timeoutInterval = 20

            let (statusData, statusResponse) = try await session.data(for: statusRequest)
            try Self.checkHTTP(statusResponse)
            guard let state = try? decoder.decode(RelayResultResponse.self, from: statusData) else { throw RelayError.invalidResponse }

            switch state.status.lowercased() {
            case "failed", "cancelled": throw RelayError.jobFailed(state.message ?? "The pairing host could not complete the request.")
            case "completed":
                guard let encoded = state.fileBase64,
                      let fileData = Data(base64Encoded: encoded),
                      !fileData.isEmpty else { throw RelayError.missingPayload }
                return (fileData, state.fileName ?? "ios-pairing.rppairing")
            default: continue
            }
        }
        throw RelayError.timedOut
    }

    private static func checkHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw RelayError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw RelayError.jobFailed("Relay returned HTTP \(http.statusCode). Check the server and access token.")
        }
    }
}

private struct CreateJobBody: Encodable {
    let osVersion: String
    let deviceModel: String
    let requestedFormat: String

    enum CodingKeys: String, CodingKey {
        case osVersion = "os_version"
        case deviceModel = "device_model"
        case requestedFormat = "requested_format"
    }
}
