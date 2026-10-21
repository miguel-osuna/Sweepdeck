import Foundation
import Testing
@testable import SweepdeckCore

private struct CandidateMatcherFixture {
    let storage: Fixture
    let root: AuthorizedRoot
    let seed: Metadata
    let ancestors: [String: FileIdentity]

    init() throws {
        let storage = try Fixture()
        self.storage = storage
        let seedURL = try storage.file("seed.dmg")
        let fileSystem = LocalFileSystem()
        root = try fileSystem.authorize(storage.url)
        seed = try fileSystem.metadata(seedURL)
        ancestors = try fileSystem.ancestors(of: seedURL)
    }

    func candidate(
        _ name: String,
        size: Int64,
        modified: Int64,
        modifiedNanos: Int64 = 0,
        rule: RuleID
    ) -> Candidate {
        let metadata = Metadata(identity: seed.identity, size: size, allocated: size,
                                modifiedSeconds: modified, modifiedNanos: modifiedNanos,
                                changedSeconds: modified, changedNanos: 0,
                                links: 1, flags: 0)
        let url = root.url.appendingPathComponent(name)
        let file = ScannedFile(url: url, root: root, metadata: metadata, ancestors: ancestors)
        return Candidate(file: file, rule: rule)
    }

    func dispose() { storage.dispose() }
}

private final class MatchProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var updates: [CandidateMatchProgress] = []
    private var calledOnMainThread = false

    func record(_ progress: CandidateMatchProgress, isMainThread: Bool) {
        lock.lock()
        updates.append(progress)
        calledOnMainThread = calledOnMainThread || isMainThread
        lock.unlock()
    }

    var recordedUpdates: [CandidateMatchProgress] {
        lock.lock(); defer { lock.unlock() }
        return updates
    }

    var ranOnMainThread: Bool {
        lock.lock(); defer { lock.unlock() }
        return calledOnMainThread
    }
}

struct CandidateMatcherTests {
    @Test func filtersPathCaseInsensitivelyAndByCategory() async throws {
        let fixture = try CandidateMatcherFixture()
        defer { fixture.dispose() }
        let candidates = [
            fixture.candidate("Archive.DMG", size: 30, modified: 30, rule: .installers),
            fixture.candidate("archive-notes.log", size: 20, modified: 20, rule: .logs),
            fixture.candidate("Other.dmg", size: 10, modified: 10, rule: .installers)
        ]

        let result = await CandidateMatcher.match(candidates: candidates, query: "ARCHIVE", category: .installers, sort: .size)

        #expect(result.keys.sorted { $0.rawValue < $1.rawValue } == [.installers])
        #expect(result[.installers, default: []].map(\.url.lastPathComponent) == ["Archive.DMG"])
    }

    @Test func sortsLargestFirst() async throws {
        let fixture = try CandidateMatcherFixture()
        defer { fixture.dispose() }
        let candidates = [
            fixture.candidate("Small.dmg", size: 10, modified: 10, rule: .installers),
            fixture.candidate("Large.dmg", size: 90, modified: 90, rule: .installers)
        ]

        let result = await CandidateMatcher.match(candidates: candidates, query: "", category: nil, sort: .size)

        #expect(result[.installers, default: []].map(\.url.lastPathComponent) == ["Large.dmg", "Small.dmg"])
    }

    @Test func usesPathAsDeterministicTieBreaker() async throws {
        let fixture = try CandidateMatcherFixture()
        defer { fixture.dispose() }
        let candidates = [
            fixture.candidate("z-last.dmg", size: 10, modified: 10, rule: .installers),
            fixture.candidate("a-first.dmg", size: 10, modified: 10, rule: .installers)
        ]

        let bySize = await CandidateMatcher.match(candidates: candidates, query: "", category: nil, sort: .size)
        let byAge = await CandidateMatcher.match(candidates: candidates, query: "", category: nil, sort: .oldest)

        #expect(bySize[.installers, default: []].map(\.url.lastPathComponent) == ["a-first.dmg", "z-last.dmg"])
        #expect(byAge[.installers, default: []].map(\.url.lastPathComponent) == ["a-first.dmg", "z-last.dmg"])
    }

    @Test func sortsNamesNaturally() async throws {
        let fixture = try CandidateMatcherFixture()
        defer { fixture.dispose() }
        let candidates = [
            fixture.candidate("file-10.dmg", size: 10, modified: 10, rule: .installers),
            fixture.candidate("file-2.dmg", size: 20, modified: 20, rule: .installers)
        ]

        let result = await CandidateMatcher.match(candidates: candidates, query: "", category: nil, sort: .name)

        #expect(result[.installers, default: []].map(\.url.lastPathComponent) == ["file-2.dmg", "file-10.dmg"])
    }

    @Test func sortsOldestFirst() async throws {
        let fixture = try CandidateMatcherFixture()
        defer { fixture.dispose() }
        let candidates = [
            fixture.candidate("Newer.dmg", size: 10, modified: 200, rule: .installers),
            fixture.candidate("Older.dmg", size: 20, modified: 100, rule: .installers)
        ]

        let result = await CandidateMatcher.match(candidates: candidates, query: "", category: nil, sort: .oldest)

        #expect(result[.installers, default: []].map(\.url.lastPathComponent) == ["Older.dmg", "Newer.dmg"])
    }

    @Test func oldestFallbackUsesSubsecondModificationTime() async throws {
        let fixture = try CandidateMatcherFixture()
        defer { fixture.dispose() }
        let candidates = [
            fixture.candidate("z-older.dmg", size: 10, modified: 100, modifiedNanos: 100_000_000, rule: .installers),
            fixture.candidate("a-newer.dmg", size: 20, modified: 100, modifiedNanos: 200_000_000, rule: .installers)
        ]

        let result = await CandidateMatcher.match(candidates: candidates, query: "", category: nil, sort: .oldest)

        #expect(result[.installers, default: []].map(\.url.lastPathComponent) == ["z-older.dmg", "a-newer.dmg"])
    }

    @Test func rustBatchSortMatchesSwiftReferenceForLargeASCIIResults() throws {
        let fixture = try CandidateMatcherFixture()
        defer { fixture.dispose() }
        var candidates: [Candidate] = []
        candidates.reserveCapacity(3_000)
        for index in 0..<3_000 {
            let size = Int64((index * 7_919) % 257)
            let modifiedSeconds = Int64(index % 101)
            let modifiedNanos = Int64((index * 37) % 1_000_000_000)
            let rule: RuleID = index.isMultiple(of: 2) ? .installers : .oldDownloads
            candidates.append(fixture.candidate(
                "item-\(index).dmg",
                size: size,
                modified: modifiedSeconds,
                modifiedNanos: modifiedNanos,
                rule: rule
            ))
        }

        let expectedBySize: [Candidate] = candidates.sorted { (left: Candidate, right: Candidate) in
            left.size == right.size ? left.id < right.id : left.size > right.size
        }
        let expectedByAge: [Candidate] = candidates.sorted { (left: Candidate, right: Candidate) in
            let leftMetadata = left.file.metadata
            let rightMetadata = right.file.metadata
            if leftMetadata.modifiedSeconds != rightMetadata.modifiedSeconds {
                return leftMetadata.modifiedSeconds < rightMetadata.modifiedSeconds
            }
            if leftMetadata.modifiedNanos != rightMetadata.modifiedNanos {
                return leftMetadata.modifiedNanos < rightMetadata.modifiedNanos
            }
            return left.id < right.id
        }
        let actualBySize = RustCandidateSorter.sorted(candidates, by: .size)
        let actualByAge = RustCandidateSorter.sorted(candidates, by: .oldest)

        #expect(actualBySize?.map(\.id) == expectedBySize.map(\.id))
        #expect(actualByAge?.map(\.id) == expectedByAge.map(\.id))

        if ProcessInfo.processInfo.environment["SWEEPDECK_PERF_BENCHMARK"] == "1" {
            let rustMedian = medianNanoseconds(repeating: 11) {
                _ = RustCandidateSorter.sorted(candidates, by: .size)
            }
            let swiftMedian = medianNanoseconds(repeating: 11) {
                _ = candidates.sorted { left, right in
                    left.size == right.size ? left.id < right.id : left.size > right.size
                }
            }
            print("3,000 candidate size sort median: Rust FFI \(rustMedian) ns; Swift \(swiftMedian) ns")
        }
    }

    @Test func rustBatchSortFallsBackForNonASCIIPaths() throws {
        let fixture = try CandidateMatcherFixture()
        defer { fixture.dispose() }
        let candidates = (0..<RustCandidateSorter.minimumBatchSize).map { index in
            fixture.candidate("item-\(index).dmg", size: Int64(index), modified: Int64(index), rule: .installers)
        } + [fixture.candidate("café.dmg", size: 10_000, modified: 1, rule: .installers)]

        #expect(RustCandidateSorter.sorted(candidates, by: .size) == nil)
    }

    @Test func rustSorterUsesBatchThresholdAndFallsBackForNameSort() throws {
        let fixture = try CandidateMatcherFixture()
        defer { fixture.dispose() }
        let belowThreshold = (0..<(RustCandidateSorter.minimumBatchSize - 1)).map { index in
            fixture.candidate("below-\(index).dmg", size: Int64(index), modified: Int64(index), rule: .installers)
        }
        let atThreshold = (0..<RustCandidateSorter.minimumBatchSize).map { index in
            fixture.candidate("at-\(index).dmg", size: Int64(index), modified: Int64(index), rule: .installers)
        }

        #expect(RustCandidateSorter.sorted(belowThreshold, by: .size) == nil)
        #expect(RustCandidateSorter.sorted(atThreshold, by: .name) == nil)
        let sortedAtThreshold = RustCandidateSorter.sorted(atThreshold, by: .size)
        let expected = atThreshold.sorted { left, right in
            left.size == right.size ? left.id < right.id : left.size > right.size
        }
        #expect(sortedAtThreshold?.map(\.id) == expected.map(\.id))
    }

    @MainActor @Test func reportsBatchProgressFromOffMainThreadMatcher() async throws {
        let fixture = try CandidateMatcherFixture()
        defer { fixture.dispose() }
        let candidates = (0..<3_000).map { index in
            fixture.candidate("item-\(index).dmg", size: Int64(index + 1), modified: Int64(index), rule: .installers)
        }
        let progress = MatchProgressRecorder()

        _ = await CandidateMatcher.match(candidates: candidates, query: "item-", category: nil, sort: .name) { update in
            progress.record(update, isMainThread: Thread.isMainThread)
        }

        #expect(!progress.ranOnMainThread)
        #expect(progress.recordedUpdates == [
            CandidateMatchProgress(processed: 1_024, total: 3_000),
            CandidateMatchProgress(processed: 2_048, total: 3_000),
            CandidateMatchProgress(processed: 3_000, total: 3_000)
        ])
    }
}

private func medianNanoseconds(repeating count: Int, operation: () -> Void) -> Int64 {
    let samples = (0..<count).map { _ -> Int64 in
        let start = ContinuousClock.now
        operation()
        let elapsed = start.duration(to: .now).components
        return elapsed.seconds * 1_000_000_000 + elapsed.attoseconds / 1_000_000_000
    }
    return samples.sorted()[samples.count / 2]
}
