//
//  DataStore.swift
//  Clocklet
//

import Foundation

enum DataStoreError: LocalizedError {
    case encodingFailed
    case writeFailed(Error)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode data"
        case .writeFailed(let error):
            return "Failed to write data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class DataStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not locate Application Support directory")
        }
        let clockletDir = appSupport.appendingPathComponent("Clocklet", isDirectory: true)
        try? FileManager.default.createDirectory(at: clockletDir, withIntermediateDirectories: true)
        self.fileURL = clockletDir.appendingPathComponent("data.json")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> ClockletData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ClockletData()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(ClockletData.self, from: data)
        } catch {
            throw DataStoreError.decodingFailed(error)
        }
    }

    func save(_ data: ClockletData) throws {
        guard let jsonData = try? encoder.encode(data) else {
            throw DataStoreError.encodingFailed
        }

        do {
            // Atomic write: writes to temp file then renames
            try jsonData.write(to: fileURL, options: .atomic)
        } catch {
            throw DataStoreError.writeFailed(error)
        }
    }

    /// Returns the path to the data file (for debugging)
    var dataFilePath: String {
        fileURL.path
    }
}
