import Foundation

public protocol TrashService: Sendable {
    func move(_ candidate: Candidate, validate: @Sendable () throws -> Void) throws -> URL
}
public struct MacTrashService: TrashService {
    public init() {}
    public func move(_ candidate: Candidate, validate: @Sendable () throws -> Void) throws -> URL {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var outcome: Result<URL, Error> = .failure(SweepError.refused("File coordination did not complete."))
        coordinator.coordinate(writingItemAt: candidate.url, options: .forDeleting, error: &coordinationError) { coordinated in
            outcome = Result {
                try Task.checkCancellation()
                guard coordinated.path == candidate.url.path else { throw SweepError.refused("The file was redirected during coordination.") }
                try validate()
                var result: NSURL?
                try FileManager.default.trashItem(at: coordinated, resultingItemURL: &result)
                return (result as URL?) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash")
            }
        }
        if let coordinationError { throw coordinationError }
        return try outcome.get()
    }
}
public actor CleanupExecutor {
    private let validator: SafetyValidator
    private let trash: any TrashService
    public init(fileSystem: any FileSystem = LocalFileSystem(), trash: any TrashService = MacTrashService()) {
        validator = SafetyValidator(fileSystem: fileSystem); self.trash = trash
    }
    public func preview(_ candidates: [Candidate], roots: [AuthorizedRoot], settings: Preferences) -> CleanupPlan {
        var ready: [Candidate] = [], rejected: [OperationItem] = []
        var seen = Set<String>()
        for candidate in candidates where seen.insert(candidate.id).inserted {
            do {
                try Task.checkCancellation()
                try validator.validate(candidate, roots: roots, settings: settings)
                ready.append(candidate)
            } catch { rejected.append(OperationItem(path: candidate.id, status: .rejected, message: error.localizedDescription)) }
        }
        return CleanupPlan(ready: ready, rejected: rejected)
    }
    /// Reports ready items handled on the first item, every 16 items, and at completion.
    public func execute(_ plan: CleanupPlan, roots: [AuthorizedRoot], settings: Preferences, confirmed: Bool,
                        progress: @Sendable (Int) async -> Void = { _ in }) async -> OperationRecord {
        var items = plan.rejected
        var completed = 0
        for candidate in plan.ready {
            if Task.isCancelled {
                items.append(OperationItem(path: candidate.id, status: .cancelled, message: "Cancelled before moving this file."))
            } else if !confirmed || Date().timeIntervalSince(plan.created) >= 300 {
                items.append(OperationItem(path: candidate.id, status: .rejected, message: "Confirmation is missing or the preview expired. Preview again."))
            } else {
                do {
                    try validator.validate(candidate, roots: roots, settings: settings)
                    do {
                        let validator = self.validator
                        let target = try trash.move(candidate) { try validator.validate(candidate, roots: roots, settings: settings) }
                        items.append(OperationItem(path: candidate.id, status: .trashed, message: "Moved to Trash; disk space is not yet reclaimed.", trashPath: target.path))
                    } catch {
                        items.append(OperationItem(path: candidate.id, status: error is CancellationError ? .cancelled : .failed, message: error.localizedDescription))
                    }
                } catch {
                    items.append(OperationItem(path: candidate.id, status: .rejected, message: error.localizedDescription))
                }
            }
            completed += 1
            if completed == 1 || completed.isMultiple(of: 16) || completed == plan.ready.count {
                await progress(completed)
            }
            await Task.yield()
        }
        return OperationRecord(items: items)
    }
}
