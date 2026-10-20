import Foundation
import Testing
@testable import SweepdeckCore

@Test func missingFilesAndNewRepositoryMarkersAreRejected() async throws {
    let f = try Fixture(); defer { f.dispose() }
    let file = try f.file("nested/a.dmg")
    let roots = [try LocalFileSystem().authorize(f.url)]
    let report = await FolderScanner().scan(roots: roots, settings: Preferences())
    let executor = CleanupExecutor(trash: RefusingTrash())
    _ = try f.file("nested/.git")
    let repository = await executor.preview(report.candidates, roots: roots, settings: Preferences())
    #expect(repository.ready.isEmpty)
    try FileManager.default.removeItem(at: f.url.appendingPathComponent("nested/.git"))
    try FileManager.default.removeItem(at: file)
    let missing = await executor.preview(report.candidates, roots: roots, settings: Preferences())
    #expect(missing.ready.isEmpty)
    #expect(missing.rejected.count == 1)
}

@Test func disabledRulesAndNewExclusionsAreRechecked() async throws {
    let f = try Fixture(); defer { f.dispose() }
    let file = try f.file("a.dmg")
    let roots = [try LocalFileSystem().authorize(f.url)]
    let report = await FolderScanner().scan(roots: roots, settings: Preferences())
    var disabled = Preferences(); disabled.enabledRules = []
    let excludedReport = await FolderScanner().scan(roots: roots, settings: disabled)
    #expect(excludedReport.candidates.isEmpty)
    let executor = CleanupExecutor(trash: RefusingTrash())
    let changed = await executor.preview(report.candidates, roots: roots, settings: disabled)
    #expect(changed.ready.isEmpty)
    var excluded = Preferences(); excluded.excludedPaths = [file.path]
    let newExclusion = await executor.preview(report.candidates, roots: roots, settings: excluded)
    #expect(newExclusion.ready.isEmpty)
}

@Test func rootReplacementIsRejected() async throws {
    let f = try Fixture(); defer { f.dispose() }
    let folder = f.url.appendingPathComponent("chosen")
    _ = try f.file("chosen/a.dmg")
    let root = try LocalFileSystem().authorize(folder)
    try FileManager.default.moveItem(at: folder, to: f.url.appendingPathComponent("old"))
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    #expect(throws: (any Error).self) { try LocalFileSystem().validateRoot(root) }
    let result = await FolderScanner().scan(roots: [root], settings: Preferences())
    #expect(result.files.isEmpty)
    #expect(result.progress.errors == 1)
}

struct DeniedFileSystem: FileSystem {
    let local = LocalFileSystem()
    func metadata(_ url: URL) throws -> Metadata { try local.metadata(url) }
    func ancestors(of url: URL) throws -> [String: FileIdentity] { try local.ancestors(of: url) }
    func validateRoot(_ root: AuthorizedRoot) throws { throw SweepError.refused("Permission unavailable") }
    func checkResource(_ url: URL) throws { throw SweepError.refused("Unsupported volume capabilities") }
}

@Test func dependencyAndPermissionFailuresStayClosed() async throws {
    let f = try Fixture(); defer { f.dispose() }
    _ = try f.file("a.dmg")
    let roots = [try LocalFileSystem().authorize(f.url)]
    let report = await FolderScanner(fileSystem: DeniedFileSystem()).scan(roots: roots, settings: Preferences())
    #expect(report.candidates.isEmpty)
    #expect(report.progress.errors == 1)
    let allowed = await FolderScanner().scan(roots: roots, settings: Preferences())
    let preview = await CleanupExecutor(fileSystem: DeniedFileSystem(), trash: RefusingTrash())
        .preview(allowed.candidates, roots: roots, settings: Preferences())
    #expect(preview.ready.isEmpty)
    #expect(preview.rejected.count == 1)
}

@Test func executionCancellationPreservesUnprocessedFiles() async throws {
    let f = try Fixture(); defer { f.dispose() }
    _ = try f.file("a.dmg")
    let roots = [try LocalFileSystem().authorize(f.url)]
    let report = await FolderScanner().scan(roots: roots, settings: Preferences())
    let executor = CleanupExecutor(trash: RefusingTrash())
    let preview = await executor.preview(report.candidates, roots: roots, settings: Preferences())
    let task = Task { await executor.execute(preview, roots: roots, settings: Preferences(), confirmed: true) }
    task.cancel()
    let result = await task.value
    #expect(result.items[0].status == .cancelled)
    #expect(FileManager.default.fileExists(atPath: f.url.appendingPathComponent("a.dmg").path))
}

@Test func historyIsBoundedAndDatesRetained() {
    var state = SavedState()
    let items = (0..<1200).map { OperationItem(path: "/fixture/\($0)", status: .failed, message: "Fixture") }
    let operation = OperationRecord(items: items)
    state.record(operation)
    #expect(state.history[0].items.count == 1000)
    #expect(state.history[0].date == operation.date)
    #expect(state.history[0].id == operation.id)
}

@Test func nestedPackageRootIsRefused() throws {
    let f = try Fixture(); defer { f.dispose() }
    _ = try f.file("Sample.pages/inner/a.dmg")
    #expect(throws: (any Error).self) { try LocalFileSystem().authorize(f.url.appendingPathComponent("Sample.pages/inner")) }
}

@Test func selectionDeselectsWithoutAffectingOtherItems() async throws {
    let f = try Fixture(); defer { f.dispose() }
    _ = try f.file("a.dmg", bytes: 100); _ = try f.file("b.dmg", bytes: 200)
    let report = await FolderScanner().scan(roots: [try LocalFileSystem().authorize(f.url)], settings: Preferences())
    var selection = Selection()
    for candidate in report.candidates { selection.toggle(candidate) }
    #expect(selection.bytes(in: report.candidates) == 300)
    selection.toggle(report.candidates[0])
    #expect(selection.bytes(in: report.candidates) == 100)
}
