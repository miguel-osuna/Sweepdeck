import Foundation

public struct DiskExplorerEntry: Identifiable, Equatable, Sendable {
    public let url: URL
    public let size: Int64
    public let count: Int
    public let directory: Bool

    public var id: String { url.path }
}

public struct ExplorerMatchProgress: Equatable, Sendable {
    public let processed: Int
    public let total: Int

    init(processed: Int, total: Int) {
        self.processed = processed
        self.total = total
    }
}

public enum DiskExplorerMatcher {
    public nonisolated static func entries(
        files: [ScannedFile],
        roots: [AuthorizedRoot],
        location: URL?,
        extensionFilter: String,
        minimumBytes: Int64,
        modifiedBefore: Date?,
        onProgress: (@Sendable (ExplorerMatchProgress) -> Void)? = nil
    ) async -> [DiskExplorerEntry] {
        guard !Task.isCancelled else { return [] }
        if let location,
           !roots.contains(where: { PathPolicy.contains(location.path, in: $0.url.path) }) {
            return []
        }

        var eligible: [ScannedFile] = []
        eligible.reserveCapacity(files.count)
        for (index, file) in files.enumerated() {
            if index.isMultiple(of: 256), Task.isCancelled { return [] }
            let isAuthorized = roots.contains { PathPolicy.contains(file.id, in: $0.url.path) }
            if isAuthorized
                && (extensionFilter.isEmpty || file.url.pathExtension.localizedCaseInsensitiveContains(extensionFilter))
                && file.metadata.size >= minimumBytes
                && (modifiedBefore.map { file.metadata.modified <= $0 } ?? true) {
                eligible.append(file)
            }

            let processed = index + 1
            if processed.isMultiple(of: 1_024) || processed == files.count {
                onProgress?(ExplorerMatchProgress(processed: processed, total: files.count))
                await Task.yield()
            }
        }
        guard !Task.isCancelled else { return [] }

        if let location {
            var groups: [String: DiskExplorerAggregate] = [:]
            for (index, file) in eligible.enumerated() {
                if index.isMultiple(of: 256), Task.isCancelled { return [] }
                guard PathPolicy.contains(file.id, in: location.path) else { continue }
                let relativePath = file.id.dropFirst(location.path.count)
                guard let component = relativePath.split(separator: "/").first else { continue }
                let childURL = location.appendingPathComponent(String(component))
                groups[childURL.path, default: DiskExplorerAggregate()].add(file)
            }
            guard !Task.isCancelled else { return [] }
            return groups.map { path, aggregate in
                DiskExplorerEntry(
                    url: URL(fileURLWithPath: path),
                    size: aggregate.size,
                    count: aggregate.count,
                    directory: aggregate.count != 1 || aggregate.singleFilePath != path
                )
            }.sorted(by: diskExplorerOrder)
        }

        var totals: [String: DiskExplorerAggregate] = [:]
        for (index, file) in eligible.enumerated() {
            if index.isMultiple(of: 256), Task.isCancelled { return [] }
            for root in roots where PathPolicy.contains(file.id, in: root.url.path) {
                totals[root.url.path, default: DiskExplorerAggregate()].add(file)
            }
        }
        guard !Task.isCancelled else { return [] }

        return roots.map { root in
            let aggregate = totals[root.url.path] ?? DiskExplorerAggregate()
            return DiskExplorerEntry(url: root.url, size: aggregate.size, count: aggregate.count, directory: true)
        }.sorted(by: diskExplorerOrder)
    }
}

private struct DiskExplorerAggregate {
    private(set) var size: Int64 = 0
    private(set) var count = 0
    private(set) var singleFilePath: String?

    mutating func add(_ file: ScannedFile) {
        size += file.metadata.size
        count += 1
        singleFilePath = count == 1 ? file.id : nil
    }
}

private func diskExplorerOrder(_ left: DiskExplorerEntry, _ right: DiskExplorerEntry) -> Bool {
    left.size == right.size ? left.id < right.id : left.size > right.size
}
