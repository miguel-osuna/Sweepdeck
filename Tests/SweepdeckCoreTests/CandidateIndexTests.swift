import Foundation
import Testing
@testable import SweepdeckCore

struct CandidateIndexFixture {
    @Test func looksUpManyCandidatesByPath() async throws {
        let fixture = try Fixture(); defer { fixture.dispose() }
        _ = try fixture.file("seed.dmg")
        let roots = [try LocalFileSystem().authorize(fixture.url)]
        let report = await FolderScanner().scan(roots: roots, settings: Preferences())
        let seed = try #require(report.candidates.first)
        let candidates = (0..<20_000).map { index in
            let url = fixture.url.appendingPathComponent("candidate-\(index).dmg")
            let file = ScannedFile(url: url, root: seed.file.root, metadata: seed.file.metadata, ancestors: seed.file.ancestors)
            return Candidate(file: file, rule: seed.rule)
        }

        let candidateIndex = CandidateIndex(candidates)
        #expect(candidateIndex.count == candidates.count)
        #expect(candidates.allSatisfy { candidateIndex.candidate(atPath: $0.id)?.id == $0.id })
        #expect(candidateIndex.candidate(atPath: fixture.url.appendingPathComponent("missing.dmg").path) == nil)
    }
}
