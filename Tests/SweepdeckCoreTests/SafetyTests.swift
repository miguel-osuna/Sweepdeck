import Foundation
import Testing
@testable import SweepdeckCore

@Test func pathBoundaries() {
    #expect(PathPolicy.contains("/chosen/sub/file.dmg", in: "/chosen"))
    #expect(!PathPolicy.contains("/chosen-elsewhere/file.dmg", in: "/chosen"))
    #expect(!PathPolicy.contains("/chosen/../secret", in: "/chosen"))
}

@Test(arguments: ["/System/cache.log", "/Library/test.dmg", "/usr/bin/a", "/Users/a/.ssh/key",
                  "/Users/a/Downloads/.env.local", "/Users/a/Pictures/Mine.photoslibrary/a",
                  "/Users/a/Library/Keychains/a", "/Users/a/Downloads/local.sqlite",
                  "/Users/a/Downloads/project/.git/config", "/Volumes/Backup/a"])
func sensitivePaths(path: String) {
    #expect(PathPolicy.isProtected(path))
}
