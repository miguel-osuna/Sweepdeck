import Foundation

public enum PathPolicy {
    public static func contains(_ child: String, in parent: String) -> Bool {
        guard !child.split(separator: "/").contains(".."), !parent.isEmpty else { return false }
        let trimmed = parent.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalized = parent == "/" ? "/" : "/" + trimmed
        return child == normalized || child.hasPrefix(normalized == "/" ? "/" : normalized + "/")
    }
    public static func isProtected(_ path: String) -> Bool {
        let components = path.lowercased().split(separator: "/").map(String.init)
        let system = ["/System", "/Library", "/Applications", "/usr", "/bin", "/sbin", "/etc", "/dev", "/Volumes",
                      "/private/etc", "/private/var/db", "/private/var/root", "/private/var/vm", "/private/var/log"]
        if system.contains(where: { contains(path.lowercased(), in: $0.lowercased()) }) { return true }
        let names: Set<String> = ["library", "node_modules", "keychains", "containers", "group containers", "mobile documents",
                                 "cloudstorage", "backups.backupdb", "docker", "volumes", "onedrive", "dropbox", "google drive"]
        let extensions: Set<String> = ["photoslibrary", "photolibrary", "app", "framework", "bundle", "keychain", "keychain-db",
                                      "sqlite", "sqlite3", "db", "pem", "key", "p12", "pfx", "kdbx", "sparsebundle", "sparseimage",
                                      "pages", "numbers", "keynote", "rtfd"]
        return components.contains { part in
            part.hasPrefix(".") || names.contains(part) || part.hasPrefix("onedrive") || part.hasPrefix("dropbox") ||
            extensions.contains((part as NSString).pathExtension)
        }
    }
}

public struct SafetyValidator: Sendable {
    public let fileSystem: any FileSystem
    public init(fileSystem: any FileSystem = LocalFileSystem()) { self.fileSystem = fileSystem }
    public func validate(_ candidate: Candidate, roots: [AuthorizedRoot], settings: Preferences) throws {
        let file = candidate.file
        guard roots.contains(file.root) else { throw SweepError.refused("Folder authorization was removed or changed. Choose it again and rescan.") }
        guard file.url.path != file.root.url.path, PathPolicy.contains(file.url.path, in: file.root.url.path),
              !PathPolicy.isProtected(file.url.path), !settings.excludes(file.url) else {
            throw SweepError.refused("This path is protected, excluded, or outside its authorized folder.")
        }
        try fileSystem.validateRoot(file.root)
        let ancestors = try fileSystem.ancestors(of: file.url)
        guard ancestors == file.ancestors else { throw SweepError.refused("A parent folder changed. Rescan before continuing.") }
        let current = try fileSystem.metadata(file.url)
        guard current == file.metadata, current.isRegular, current.links == 1,
              current.identity.device == file.root.identity.device else {
            throw SweepError.refused("The file changed, moved, or has multiple hard links. Rescan before continuing.")
        }
        try fileSystem.checkResource(file.url)
        guard RuleRegistry.classify(file, settings: settings) == candidate.rule else {
            throw SweepError.refused("This file no longer matches the selected cleanup rule.")
        }
    }
}
