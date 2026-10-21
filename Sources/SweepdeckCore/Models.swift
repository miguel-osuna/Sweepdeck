import Foundation

public enum SweepError: Error, LocalizedError, Sendable {
    case refused(String)
    public var errorDescription: String? { if case .refused(let reason) = self { reason } else { nil } }
}
public struct FileIdentity: Codable, Hashable, Sendable {
    public let device: Int32
    public let inode: UInt64
    public let mode: UInt16
    public let owner: UInt32
}
public struct Metadata: Codable, Hashable, Sendable {
    public let identity: FileIdentity
    public let size: Int64
    public let allocated: Int64
    public let modifiedSeconds: Int64
    public let modifiedNanos: Int64
    public let changedSeconds: Int64
    public let changedNanos: Int64
    public let links: UInt16
    public let flags: UInt32
    public var modified: Date {
        Date(timeIntervalSince1970: Double(modifiedSeconds) + Double(modifiedNanos) / 1_000_000_000)
    }
    public var isDirectory: Bool { identity.mode & 0o170000 == 0o040000 }
    public var isRegular: Bool { identity.mode & 0o170000 == 0o100000 }
    public var isSymlink: Bool { identity.mode & 0o170000 == 0o120000 }
}
public struct AuthorizedRoot: Codable, Hashable, Identifiable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let identity: FileIdentity
    public let ancestors: [String: FileIdentity]
}
public enum RuleID: String, Codable, CaseIterable, Identifiable, Sendable {
    case installers, oldDownloads, logs, largeFiles
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .installers: "Old installers"
        case .oldDownloads: "Older downloads"
        case .logs: "Old diagnostic logs"
        case .largeFiles: "Large files"
        }
    }
    public var symbol: String {
        switch self {
        case .installers: "shippingbox"
        case .oldDownloads: "arrow.down.circle"
        case .logs: "doc.text"
        case .largeFiles: "doc.zipper"
        }
    }
    public var reason: String {
        switch self {
        case .installers: "An older installer. Keep it if you need it for reinstalling or offline use."
        case .oldDownloads: "An older file in a Downloads folder. Age does not mean it is unnecessary."
        case .logs: "An older log. It may still be useful for diagnostics or record keeping."
        case .largeFiles: "Its size exceeds your threshold. Size alone does not make a file disposable."
        }
    }
}
public enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }
}
public struct Preferences: Codable, Equatable, Sendable {
    public var roots: [AuthorizedRoot] = []
    public var excludedPaths: [String] = []
    public var enabledRules = Set(RuleID.allCases)
    public var ageDays: Int = 60
    public var minimumLargeMB: Int = 500
    public var appearance: String = "System"
    public init() {}
    public var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearance) ?? .system }
        set { appearance = newValue.rawValue }
    }
    public var boundedAgeDays: Int { min(3650, max(1, ageDays)) }
    public var largeBytes: Int64 { Int64(min(1_000_000, max(1, minimumLargeMB))) * 1_000_000 }
    public func excludes(_ url: URL) -> Bool { excludedPaths.contains { PathPolicy.contains(url.path, in: $0) } }
}
public struct ScannedFile: Identifiable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let root: AuthorizedRoot
    public let metadata: Metadata
    public let ancestors: [String: FileIdentity]
}
public struct Candidate: Identifiable, Sendable {
    public var id: String { url.path }
    public let file: ScannedFile
    public let rule: RuleID
    public var url: URL { file.url }
    public var size: Int64 { file.metadata.size }
    public var risk: String { "Review Required" }
    public var regeneration: String { "Not guaranteed. Keep any file you may need again." }
}

public struct CandidateIndex: Sendable {
    private let index: [String: Candidate]
    public var count: Int { index.count }

    public init(_ candidates: [Candidate]) {
        var index: [String: Candidate] = [:]
        index.reserveCapacity(candidates.count)
        for candidate in candidates where index[candidate.id] == nil {
            index[candidate.id] = candidate
        }
        self.index = index
    }

    public func candidate(atPath path: String) -> Candidate? { index[path] }
}
public struct Selection: Sendable {
    public var ids: Set<String> = []
    public init() {}
    public mutating func toggle(_ item: Candidate) {
        if !ids.insert(item.id).inserted { ids.remove(item.id) }
    }
    public func bytes(in candidates: [Candidate]) -> Int64 {
        candidates.filter { ids.contains($0.id) }.reduce(0) { $0 + $1.size }
    }
}
public struct ScanProgress: Sendable {
    public var visited = 0
    public var candidates = 0
    public var skipped = 0
    public var errors = 0
    public init() {}
}
public struct ScanReport: Sendable {
    public var files: [ScannedFile] = []
    public var candidates: [Candidate] = []
    public var issues: [String] = []
    public var progress = ScanProgress()
    public var started = Date()
    public var finished = Date()
    public var cancelled = false
    public var truncated = false
    public init() {}
}
public enum OperationStatus: String, Codable, Sendable { case trashed, rejected, failed, cancelled }
public struct OperationItem: Codable, Identifiable, Sendable {
    public let id: UUID
    public let path: String
    public let status: OperationStatus
    public let message: String
    public let trashPath: String?
    public init(path: String, status: OperationStatus, message: String, trashPath: String? = nil) {
        self.id = UUID(); self.path = path; self.status = status
        self.message = message; self.trashPath = trashPath
    }
}
public struct CleanupPlan: Identifiable, Sendable {
    public let id = UUID()
    public let created = Date()
    public let ready: [Candidate]
    public let rejected: [OperationItem]
    public var bytes: Int64 { ready.reduce(0) { $0 + $1.size } }
}
public struct OperationRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let items: [OperationItem]
    public init(items: [OperationItem]) { id = UUID(); date = Date(); self.items = items }
    init(id: UUID, date: Date, items: [OperationItem]) { self.id = id; self.date = date; self.items = items }
}
