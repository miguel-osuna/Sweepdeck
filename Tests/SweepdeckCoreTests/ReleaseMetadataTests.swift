import Testing
@testable import SweepdeckCore

@Test func releaseMetadataReadsBundleVersionAndBuildNumber() {
    let info: [String: Any] = [
        "CFBundleShortVersionString": "0.0.0",
        "CFBundleVersion": "1"
    ]

    #expect(ReleaseMetadata.shortVersion(from: info) == "0.0.0")
    #expect(ReleaseMetadata.buildNumber(from: info) == "1")
}

@Test func releaseMetadataFallsBackWhenBundleValuesAreMissingOrEmpty() {
    #expect(ReleaseMetadata.shortVersion(from: nil) == "0.0.0")
    #expect(ReleaseMetadata.buildNumber(from: nil) == "0")

    let empty: [String: Any] = [
        "CFBundleShortVersionString": "",
        "CFBundleVersion": ""
    ]
    #expect(ReleaseMetadata.shortVersion(from: empty) == "0.0.0")
    #expect(ReleaseMetadata.buildNumber(from: empty) == "0")
}
