import Foundation
import Testing
@testable import SweepdeckCore

@Test func oversizedAndUnsupportedStateAreRejected() throws {
    let fixture = try Fixture(); defer { fixture.dispose() }
    let url = fixture.url.appendingPathComponent("state.json")
    let store = JSONStore(url: url)
    try Data(repeating: 32, count: 8_000_001).write(to: url)
    #expect(throws: (any Error).self) { try store.load() }
    var state = SavedState(); state.version = 2
    let original = try JSONEncoder().encode(state)
    try original.write(to: url)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(try Data(contentsOf: url) == original)
}

@Test func installerThresholdAndSizeClassification() async throws {
    let fixture = try Fixture(); defer { fixture.dispose() }
    _ = try fixture.file("old.dmg", bytes: 2_000_000)
    _ = try fixture.file("recent.bin", bytes: 1_000_000, old: false)
    _ = try fixture.file("small.bin", bytes: 999_999, old: false)
    var settings = Preferences(); settings.minimumLargeMB = 1
    let report = await FolderScanner().scan(roots: [try LocalFileSystem().authorize(fixture.url)], settings: settings)
    #expect(report.candidates.count == 2)
    #expect(report.candidates.first { $0.url.lastPathComponent == "old.dmg" }?.rule == .installers)
    #expect(report.candidates.first { $0.url.lastPathComponent == "recent.bin" }?.rule == .largeFiles)
}
