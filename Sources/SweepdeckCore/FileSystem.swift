import Foundation
import Darwin

public protocol FileSystem: Sendable {
    func metadata(_ url: URL) throws -> Metadata
    func ancestors(of url: URL) throws -> [String: FileIdentity]
    func validateRoot(_ root: AuthorizedRoot) throws
    func checkResource(_ url: URL) throws
}
public struct LocalFileSystem: FileSystem {
    public init() {}
    public func metadata(_ url: URL) throws -> Metadata {
        var value = stat()
        guard url.isFileURL, url.path.withCString({ lstat($0, &value) }) == 0 else {
            throw SweepError.refused("Cannot inspect \(url.lastPathComponent): \(String(cString: strerror(errno)))")
        }
        return Metadata(identity: FileIdentity(device: value.st_dev, inode: value.st_ino, mode: value.st_mode, owner: value.st_uid),
                        size: max(0, value.st_size), allocated: max(0, value.st_blocks * 512),
                        modifiedSeconds: Int64(value.st_mtimespec.tv_sec), modifiedNanos: Int64(value.st_mtimespec.tv_nsec),
                        changedSeconds: Int64(value.st_ctimespec.tv_sec), changedNanos: Int64(value.st_ctimespec.tv_nsec),
                        links: value.st_nlink, flags: value.st_flags)
    }
    public func ancestors(of url: URL) throws -> [String: FileIdentity] {
        var result: [String: FileIdentity] = [:]
        var parent = url.deletingLastPathComponent()
        while parent.path != "/" {
            let meta = try metadata(parent)
            guard meta.isDirectory, !meta.isSymlink else { throw SweepError.refused("A parent is a symbolic link or is no longer a folder: \(parent.path)") }
            let resourceValues = try parent.resourceValues(forKeys: [.isPackageKey, .isUbiquitousItemKey])
            if resourceValues.isPackage == true || resourceValues.isUbiquitousItem == true {
                throw SweepError.refused("Package and cloud-managed ancestors are protected.")
            }
            for marker in [".git", ".hg", ".svn"] {
                var value = stat()
                let code = parent.appendingPathComponent(marker).path.withCString { lstat($0, &value) }
                if code == 0 { throw SweepError.refused("Repositories and worktrees are protected.") }
                if errno != ENOENT { throw SweepError.refused("Cannot verify repository protection in a parent folder.") }
            }
            result[parent.path] = meta.identity
            parent.deleteLastPathComponent()
        }
        return result
    }
    public func checkResource(_ url: URL) throws {
        let meta = try metadata(url)
        guard !meta.isSymlink, meta.identity.owner == getuid(), meta.flags == 0 else {
            throw SweepError.refused("Links, other users' files, locked or specially managed files are excluded.")
        }
        let values = try url.resourceValues(forKeys: [.isUbiquitousItemKey, .isPackageKey, .isAliasFileKey,
                                                       .volumeIsLocalKey, .volumeIsInternalKey, .isReadableKey, .isWritableKey])
        guard values.isUbiquitousItem != true, values.isPackage != true, values.isAliasFile != true,
              values.volumeIsLocal == true, values.volumeIsInternal == true,
              values.isReadable == true, values.isWritable == true else {
            throw SweepError.refused("Cloud, external, package, alias or inaccessible items are excluded.")
        }
    }
    public func authorize(_ url: URL) throws -> AuthorizedRoot {
        guard url.isFileURL, !PathPolicy.isProtected(url.path),
              !["/", "/Users", "/private", "/private/var", "/private/var/folders", NSHomeDirectory()].contains(url.path) else {
            throw SweepError.refused("Choose a specific local folder, such as Downloads. System and home-wide scans are disabled.")
        }
        let meta = try metadata(url)
        guard meta.isDirectory else { throw SweepError.refused("Choose a folder, not a file or symbolic link.") }
        try checkResource(url)
        let parents = try ancestors(of: url.appendingPathComponent("authorization-check"))
        return AuthorizedRoot(url: url, identity: meta.identity, ancestors: parents)
    }
    public func validateRoot(_ root: AuthorizedRoot) throws {
        guard try authorize(root.url) == root else { throw SweepError.refused("The authorized folder changed. Choose it again.") }
    }
}
