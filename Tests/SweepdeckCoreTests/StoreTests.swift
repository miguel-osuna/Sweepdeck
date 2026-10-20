import Foundation
import Testing
@testable import SweepdeckCore

@Test func settingsAndHistoryRoundTrip() throws {
    let f = try Fixture(); defer { f.dispose() }
    let store = JSONStore(url: f.url.appendingPathComponent("state.json"))
    #expect(try store.load().preferences.roots.isEmpty)
    var state = SavedState()
    state.preferences.roots = [try LocalFileSystem().authorize(f.url)]
    state.preferences.ageDays = 120
    state.preferences.minimumLargeMB = 750
    state.preferences.enabledRules = [.logs]
    state.preferences.excludedPaths = ["/example/excluded"]
    state.preferences.appearance = "Dark"
    state.history = [OperationRecord(items: [OperationItem(path: "/fixture/a", status: .failed, message: "Fixture error")])]
    try store.save(state)
    let restored = try store.load()
    #expect(restored.preferences.roots == state.preferences.roots)
    #expect(restored.preferences.ageDays == 120)
    #expect(restored.preferences.minimumLargeMB == 750)
    #expect(restored.preferences.enabledRules == [.logs])
    #expect(restored.preferences.excludedPaths == ["/example/excluded"])
    #expect(restored.preferences.appearance == "Dark")
    #expect(restored.history[0].items[0].status == .failed)
    try Data("corrupt".utf8).write(to: store.url)
    #expect(throws: (any Error).self) { try store.load() }
}

@Test func preferenceThresholdsStayWithinSupportedBounds() {
    var preferences = Preferences()
    preferences.ageDays = 0
    #expect(preferences.boundedAgeDays == 1)
    preferences.ageDays = 5000
    #expect(preferences.boundedAgeDays == 3650)
    preferences.minimumLargeMB = 0
    #expect(preferences.largeBytes == 1_000_000)
    preferences.minimumLargeMB = 1_000_001
    #expect(preferences.largeBytes == 1_000_000_000_000)
}

@Test func failingStoreDoesNotSilentlyDiscard() throws {
    let f = try Fixture(); defer { f.dispose() }
    let file = try f.file("not-a-directory")
    let store = JSONStore(url: file.appendingPathComponent("state.json"))
    #expect(throws: (any Error).self) { try store.save(SavedState()) }
}
