import Foundation
import Testing
@testable import SweepdeckCore

struct Fixture {
    let url: URL
    init() throws {
        // Foundation can shorten /private/var back to the /var symlink. Keep an
        // explicit canonical fixture root to exercise the no-symlink policy.
        url = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("SweepdeckTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func file(_ name: String, bytes: Int = 128, old: Bool = true) throws -> URL {
        let target = url.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 42, count: bytes).write(to: target)
        if old { try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -100 * 86400)], ofItemAtPath: target.path) }
        return target
    }
    func dispose() { try? FileManager.default.removeItem(at: url) }
}

private final class AncestorCallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private actor ProgressRecorder {
    private var values: [Int] = []

    func append(_ value: Int) { values.append(value) }
    func snapshot() -> [Int] { values }
}

private struct CountingFileSystem: FileSystem {
    let counter: AncestorCallCounter
    private let base = LocalFileSystem()

    func metadata(_ url: URL) throws -> Metadata { try base.metadata(url) }
    func ancestors(of url: URL) throws -> [String: FileIdentity] {
        counter.increment()
        return try base.ancestors(of: url)
    }
    func validateRoot(_ root: AuthorizedRoot) throws { try base.validateRoot(root) }
    func checkResource(_ url: URL) throws { try base.checkResource(url) }
}

@Test func discoveryAndInitialSelection() async throws {
    let f = try Fixture(); defer { f.dispose() }
    _ = try f.file("old.dmg"); _ = try f.file("new.dmg", old: false)
    _ = try f.file("secret/.env"); _ = try f.file("repo/.git/config")
    _ = try f.file("repo/inside.dmg"); _ = try f.file("archive.photoslibrary/inside.dmg")
    let root = try LocalFileSystem().authorize(f.url)
    let progress = ProgressRecorder()
    let report = await FolderScanner().scan(roots: [root], settings: Preferences()) { value in
        await progress.append(value.visited)
    }
    #expect(await progress.snapshot().last == Optional(report.progress.visited))
    #expect(report.candidates.map(\.url.lastPathComponent) == ["old.dmg"])
    #expect(Selection().ids.isEmpty)
    var selection = Selection()
    selection.toggle(report.candidates[0])
    #expect(selection.bytes(in: report.candidates) == 128)
}

@Test func linksAndExclusions() async throws {
    let f = try Fixture(); defer { f.dispose() }
    let file = try f.file("excluded/a.dmg")
    try FileManager.default.createSymbolicLink(at: f.url.appendingPathComponent("linked"), withDestinationURL: file.deletingLastPathComponent())
    let hard = try f.file("hard.dmg")
    try FileManager.default.linkItem(at: hard, to: f.url.appendingPathComponent("hard2.dmg"))
    var p = Preferences(); p.excludedPaths = [file.deletingLastPathComponent().path]
    let report = await FolderScanner().scan(roots: [try LocalFileSystem().authorize(f.url)], settings: p)
    #expect(report.candidates.isEmpty)
}

@Test func overlappingAuthorizedRootsDoNotDuplicateFilesOrCandidates() async throws {
    let f = try Fixture(); defer { f.dispose() }
    _ = try f.file("nested/old.dmg", bytes: 128)
    let fileSystem = LocalFileSystem()
    let roots = [
        try fileSystem.authorize(f.url),
        try fileSystem.authorize(f.url.appendingPathComponent("nested"))
    ]
    let report = await FolderScanner().scan(roots: roots, settings: Preferences())

    #expect(report.files.count == 1)
    #expect(report.candidates.count == 1)
    #expect(report.candidates[0].url.lastPathComponent == "old.dmg")
    var selection = Selection()
    selection.toggle(report.candidates[0])
    #expect(selection.bytes(in: report.candidates) == 128)
}

@Test func scannerResolvesAncestryOncePerDirectoryAndKeepsExactSnapshots() async throws {
    let f = try Fixture(); defer { f.dispose() }
    _ = try f.file("first.dmg")
    _ = try f.file("nested/second.dmg")
    _ = try f.file("nested/deeper/third.dmg")
    let localFileSystem = LocalFileSystem()
    let root = try localFileSystem.authorize(f.url)
    let counter = AncestorCallCounter()

    let report = await FolderScanner(fileSystem: CountingFileSystem(counter: counter))
        .scan(roots: [root], settings: Preferences())

    #expect(report.files.count == 3)
    #expect(report.candidates.count == 3)
    #expect(counter.value == 2)
    for file in report.files {
        #expect(file.ancestors == (try localFileSystem.ancestors(of: file.url)))
    }
}

@Test func previewAndStaleRevalidation() async throws {
    let f = try Fixture(); defer { f.dispose() }
    let file = try f.file("old.dmg")
    let roots = [try LocalFileSystem().authorize(f.url)]
    let report = await FolderScanner().scan(roots: roots, settings: Preferences())
    let executor = CleanupExecutor(trash: RefusingTrash())
    let plan = await executor.preview(report.candidates, roots: roots, settings: Preferences())
    #expect(plan.ready.count == 1)
    #expect(FileManager.default.fileExists(atPath: file.path))
    try Data(repeating: 43, count: 128).write(to: file)
    let progress = ProgressRecorder()
    let result = await executor.execute(plan, roots: roots, settings: Preferences(), confirmed: true) { count in
        await progress.append(count)
    }
    #expect(result.items.count == 1)
    #expect(result.items[0].status == .rejected)
    #expect(await progress.snapshot() == [1])
    #expect(FileManager.default.fileExists(atPath: file.path))
}

struct RefusingTrash: TrashService {
    func move(_ candidate: Candidate, validate: @Sendable () throws -> Void) throws -> URL {
        try validate()
        throw SweepError.refused("Fixture Trash failure")
    }
}

struct FixtureTrash: TrashService {
    let destination: URL
    func move(_ candidate: Candidate, validate: @Sendable () throws -> Void) throws -> URL {
        try validate()
        if candidate.url.lastPathComponent == "fail.dmg" { throw SweepError.refused("Fixture failure") }
        let target = destination.appendingPathComponent(candidate.url.lastPathComponent)
        try FileManager.default.moveItem(at: candidate.url, to: target)
        return target
    }
}

@Test func confirmationPartialFailureAndRevocation() async throws {
    let f = try Fixture(); defer { f.dispose() }
    _ = try f.file("a.dmg"); _ = try f.file("fail.dmg")
    let trash = f.url.appendingPathComponent("fixture-trash")
    try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
    let roots = [try LocalFileSystem().authorize(f.url)]
    let report = await FolderScanner().scan(roots: roots, settings: Preferences())
    let executor = CleanupExecutor(trash: FixtureTrash(destination: trash))
    let plan = await executor.preview(report.candidates, roots: roots, settings: Preferences())
    let unconfirmed = await executor.execute(plan, roots: roots, settings: Preferences(), confirmed: false)
    #expect(unconfirmed.items.allSatisfy { $0.status == .rejected })
    let revoked = await executor.execute(plan, roots: [], settings: Preferences(), confirmed: true)
    #expect(revoked.items.allSatisfy { $0.status == .rejected })
    let progress = ProgressRecorder()
    let result = await executor.execute(plan, roots: roots, settings: Preferences(), confirmed: true) { count in
        await progress.append(count)
    }
    #expect(result.items.filter { $0.status == .trashed }.count == 1)
    #expect(result.items.filter { $0.status == .failed }.count == 1)
    #expect(await progress.snapshot() == [1, 2])
    #expect(FileManager.default.fileExists(atPath: f.url.appendingPathComponent("fail.dmg").path))
}

struct CancellingTrash: TrashService {
    func move(_ candidate: Candidate, validate: @Sendable () throws -> Void) throws -> URL {
        try validate()
        withUnsafeCurrentTask { $0?.cancel() }
        throw CancellationError()
    }
}

@Test func cleanupProgressAdvancesForCancelledItems() async throws {
    let f = try Fixture(); defer { f.dispose() }
    _ = try f.file("a.dmg"); _ = try f.file("b.dmg")
    let roots = [try LocalFileSystem().authorize(f.url)]
    let report = await FolderScanner().scan(roots: roots, settings: Preferences())
    let executor = CleanupExecutor(trash: CancellingTrash())
    let plan = await executor.preview(report.candidates, roots: roots, settings: Preferences())
    let progress = ProgressRecorder()

    let result = await executor.execute(plan, roots: roots, settings: Preferences(), confirmed: true) { count in
        await progress.append(count)
    }

    #expect(result.items.filter { $0.status == .cancelled }.count == plan.ready.count)
    #expect(await progress.snapshot() == Array(1...plan.ready.count))
}

@Test func cleanupProgressReportsBatchesAndFinalCount() async throws {
    let f = try Fixture(); defer { f.dispose() }
    for index in 0..<33 { _ = try f.file("item-\(index).dmg") }
    let trash = f.url.appendingPathComponent("fixture-trash")
    try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
    let roots = [try LocalFileSystem().authorize(f.url)]
    let report = await FolderScanner().scan(roots: roots, settings: Preferences())
    let executor = CleanupExecutor(trash: FixtureTrash(destination: trash))
    let plan = await executor.preview(report.candidates, roots: roots, settings: Preferences())
    let progress = ProgressRecorder()

    let result = await executor.execute(plan, roots: roots, settings: Preferences(), confirmed: true) { count in
        await progress.append(count)
    }

    #expect(plan.ready.count == 33)
    #expect(result.items.filter { $0.status == .trashed }.count == 33)
    #expect(await progress.snapshot() == [1, 16, 32, 33])
}

@Test func missingAndSymlinkReplacedAncestor() async throws {
    let f = try Fixture(); defer { f.dispose() }
    let file = try f.file("sub/a.dmg")
    let roots = [try LocalFileSystem().authorize(f.url)]
    let report = await FolderScanner().scan(roots: roots, settings: Preferences())
    let executor = CleanupExecutor(trash: RefusingTrash())
    try FileManager.default.moveItem(at: file.deletingLastPathComponent(), to: f.url.appendingPathComponent("moved"))
    try FileManager.default.createSymbolicLink(at: file.deletingLastPathComponent(), withDestinationURL: f.url.appendingPathComponent("moved"))
    let plan = await executor.preview(report.candidates, roots: roots, settings: Preferences())
    #expect(plan.ready.isEmpty)
    #expect(plan.rejected.count == 1)
}

@Test func cancellationAndLimits() async throws {
    let f = try Fixture(); defer { f.dispose() }
    for i in 0..<30 { _ = try f.file("\(i).dmg") }
    let roots = [try LocalFileSystem().authorize(f.url)]
    let limited = await FolderScanner(maximumEntries: 5).scan(roots: roots, settings: Preferences())
    #expect(limited.truncated)
    #expect(limited.files.count <= 5)
    let task = Task { await FolderScanner().scan(roots: roots, settings: Preferences()) }
    task.cancel()
    let cancelled = await task.value
    #expect(cancelled.cancelled)
}
