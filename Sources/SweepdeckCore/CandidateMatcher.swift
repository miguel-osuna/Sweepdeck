import Foundation

public enum CandidateSort: String, CaseIterable, Equatable, Sendable {
    case size
    case name
    case oldest
}

public struct CandidateMatchProgress: Equatable, Sendable {
    public let processed: Int
    public let total: Int

    init(processed: Int, total: Int) {
        self.processed = processed
        self.total = total
    }
}

public enum CandidateMatcher {
    public nonisolated static func match(
        candidates: [Candidate],
        query: String,
        category: RuleID?,
        sort: CandidateSort,
        onProgress: (@Sendable (CandidateMatchProgress) -> Void)? = nil
    ) async -> [RuleID: [Candidate]] {
        var filtered: [Candidate] = []
        filtered.reserveCapacity(candidates.count)

        for (index, candidate) in candidates.enumerated() {
            if index.isMultiple(of: 256), Task.isCancelled { return [:] }
            if (category == nil || candidate.rule == category)
                && (query.isEmpty || candidate.id.localizedCaseInsensitiveContains(query)) {
                filtered.append(candidate)
            }

            let processed = index + 1
            if processed.isMultiple(of: 1_024) || processed == candidates.count {
                onProgress?(CandidateMatchProgress(processed: processed, total: candidates.count))
            }
        }
        guard !Task.isCancelled else { return [:] }

        filtered.sort { left, right in
            switch sort {
            case .size:
                return left.size == right.size ? left.id < right.id : left.size > right.size
            case .name:
                let order = left.url.lastPathComponent.localizedStandardCompare(right.url.lastPathComponent)
                return order == .orderedSame ? left.id < right.id : order == .orderedAscending
            case .oldest:
                let leftDate = left.file.metadata.modified
                let rightDate = right.file.metadata.modified
                return leftDate == rightDate ? left.id < right.id : leftDate < rightDate
            }
        }
        guard !Task.isCancelled else { return [:] }

        return Dictionary(grouping: filtered, by: \.rule)
    }
}
