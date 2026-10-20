import Foundation

public struct SavedState: Codable, Sendable {
    public var version = 1
    public var preferences = Preferences()
    public var history: [OperationRecord] = []
    public var lastScan: Date?
    public init() {}
    public mutating func record(_ operation: OperationRecord) {
        history.insert(operation, at: 0)
        // Keep at most 1,000 per-item records and 50 operations locally.
        var remaining = 1_000
        history = Array(history.prefix(50)).compactMap { record in
            guard remaining > 0 else { return nil }
            let items = Array(record.items.prefix(remaining))
            remaining -= items.count
            return OperationRecord(id: record.id, date: record.date, items: items)
        }
    }
}

public struct JSONStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public static var application: JSONStore {
        JSONStore(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sweepdeck/state.json"))
    }
    public func load() throws -> SavedState {
        guard FileManager.default.fileExists(atPath: url.path) else { return SavedState() }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 8_000_001) ?? Data()
        guard data.count <= 8_000_000 else { throw SweepError.refused("The local state file is too large to load safely.") }
        let state = try JSONDecoder().decode(SavedState.self, from: data)
        guard state.version == 1 else { throw SweepError.refused("This preferences file uses an unsupported version.") }
        return state
    }
    public func save(_ state: SavedState) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        guard data.count <= 8_000_000 else { throw SweepError.refused("Local history is too large to save.") }
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
