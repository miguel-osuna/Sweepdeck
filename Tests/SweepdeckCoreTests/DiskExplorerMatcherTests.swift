import Foundation
import Testing
@testable import SweepdeckCore

private struct DiskExplorerFixture {
    let storage: Fixture
    let root: AuthorizedRoot
    let seed: Metadata
    let ancestors: [String: FileIdentity]

    init() throws {
        storage = try Fixture()
        let seedURL = try storage.file("seed.dmg")
        let fileSystem = LocalFileSystem()
        root = try fileSystem.authorize(storage.url)
        seed = try fileSystem.metadata(seedURL)
        ancestors = try fileSystem.ancestors(of: seedURL)
    }

    func file(_ path: String, size: Int64, modified: Int64) -> ScannedFile {
        let metadata = Metadata(identity: seed.identity, size: size, allocated: size,
                                modifiedSeconds: modified, modifiedNanos: 0,
                                changedSeconds: modified, changedNanos: 0,
                                links: 1, flags: 0)
        return ScannedFile(url: URL(fileURLWithPath: root.url.path).appendingPathComponent(path),
                           root: root, metadata: metadata, ancestors: ancestors)
    }

    func dispose() { storage.dispose() }
}

private final class ExplorerProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var updates: [ExplorerMatchProgress] = []
    private var calledOnMainThread = false

    func record(_ progress: ExplorerMatchProgress, isMainThread: Bool) {
        lock.lock()
        updates.append(progress)
        calledOnMainThread = calledOnMainThread || isMainThread
        lock.unlock()
    }

    var recordedUpdates: [ExplorerMatchProgress] {
        lock.lock(); defer { lock.unlock() }
        return updates
    }

    var ranOnMainThread: Bool {
        lock.lock(); defer { lock.unlock() }
        return calledOnMainThread
    }
}

struct DiskExplorerMatcherTests {
    @Test func aggregatesRootAndImmediateChildrenIncludingNestedFiles() async throws {
        let fixture = try DiskExplorerFixture()
        defer { fixture.dispose() }
        let files = [
            fixture.file("Folder/first.dmg", size: 10, modified: 100),
            fixture.file("Folder/Nested/second.log", size: 20, modified: 100),
            fixture.file("root.txt", size: 5, modified: 100)
        ]

        let roots = await DiskExplorerMatcher.entries(
            files: files, roots: [fixture.root], location: nil,
            extensionFilter: "", minimumBytes: 0, modifiedBefore: nil
        )
        let children = await DiskExplorerMatcher.entries(
            files: files, roots: [fixture.root], location: fixture.root.url,
            extensionFilter: "", minimumBytes: 0, modifiedBefore: nil
        )

        #expect(roots.count == 1)
        #expect(roots[0].url == fixture.root.url)
        #expect(roots[0].size == 35)
        #expect(roots[0].count == 3)
        #expect(roots[0].directory)
        #expect(children.map(\.url.lastPathComponent) == ["Folder", "root.txt"])
        #expect(children.map(\.size) == [30, 5])
        #expect(children.map(\.count) == [2, 1])
        #expect(children.map(\.directory) == [true, false])
    }

    @Test func filtersByExtensionSizeAndAge() async throws {
        let fixture = try DiskExplorerFixture()
        defer { fixture.dispose() }
        let files = [
            fixture.file("old.dmg", size: 30, modified: 100),
            fixture.file("recent.DMG", size: 25, modified: 200),
            fixture.file("large.log", size: 1_000, modified: 200)
        ]

        let result = await DiskExplorerMatcher.entries(
            files: files, roots: [fixture.root], location: nil,
            extensionFilter: "dmg", minimumBytes: 20,
            modifiedBefore: Date(timeIntervalSince1970: 150)
        )

        #expect(result.map(\.size) == [30])
        #expect(result.map(\.count) == [1])
    }

    @Test func ignoresFilesOutsideAuthorizedRoots() async throws {
        let fixture = try DiskExplorerFixture()
        defer { fixture.dispose() }
        let outside = ScannedFile(
            url: URL(fileURLWithPath: fixture.root.url.path + "-outside/ignored.dmg"),
            root: fixture.root,
            metadata: fixture.seed,
            ancestors: fixture.ancestors
        )

        let result = await DiskExplorerMatcher.entries(
            files: [fixture.file("inside.dmg", size: 12, modified: 100), outside],
            roots: [fixture.root], location: nil,
            extensionFilter: "", minimumBytes: 0, modifiedBefore: nil
        )

        #expect(result.count == 1)
        #expect(result[0].size == 12)
        #expect(result[0].count == 1)
    }

    @MainActor @Test func reportsBatchedProgressOffMainThreadForLargeResults() async throws {
        let fixture = try DiskExplorerFixture()
        defer { fixture.dispose() }
        let files = (0..<3_000).map { index in
            fixture.file("item-\(index).dmg", size: Int64(index + 1), modified: Int64(index))
        }
        let progress = ExplorerProgressRecorder()

        let result = await DiskExplorerMatcher.entries(
            files: files, roots: [fixture.root], location: nil,
            extensionFilter: "", minimumBytes: 0, modifiedBefore: nil
        ) { update in
            progress.record(update, isMainThread: Thread.isMainThread)
        }

        #expect(result.count == 1)
        #expect(result[0].count == 3_000)
        #expect(!progress.ranOnMainThread)
        #expect(progress.recordedUpdates == [
            ExplorerMatchProgress(processed: 1_024, total: 3_000),
            ExplorerMatchProgress(processed: 2_048, total: 3_000),
            ExplorerMatchProgress(processed: 3_000, total: 3_000)
        ])
    }
}
