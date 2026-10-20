import Foundation

public enum RuleRegistry {
    public static func classify(_ file: ScannedFile, settings: Preferences, now: Date = Date()) -> RuleID? {
        let old = now.timeIntervalSince(file.metadata.modified) >= Double(settings.boundedAgeDays) * 86400
        let ext = file.url.pathExtension.lowercased()
        if old && ["dmg", "pkg"].contains(ext) && settings.enabledRules.contains(.installers) { return .installers }
        if old && ext == "log" && settings.enabledRules.contains(.logs) { return .logs }
        if old && file.url.pathComponents.contains("Downloads") && settings.enabledRules.contains(.oldDownloads) { return .oldDownloads }
        if file.metadata.size >= settings.largeBytes && settings.enabledRules.contains(.largeFiles) { return .largeFiles }
        return nil
    }
}

public actor FolderScanner {
    private let fileSystem: any FileSystem
    private let maximumEntries: Int
    public init(fileSystem: any FileSystem = LocalFileSystem(), maximumEntries: Int = 25_000) {
        self.fileSystem = fileSystem; self.maximumEntries = max(1, maximumEntries)
    }
    public func scan(roots: [AuthorizedRoot], settings: Preferences,
                     progress: @Sendable (ScanProgress) async -> Void = { _ in }) async -> ScanReport {
        var report = ScanReport()
        var seen = Set<String>()
        outer: for root in roots {
            if Task.isCancelled { report.cancelled = true; break }
            do { try fileSystem.validateRoot(root) }
            catch { report.issues.append(error.localizedDescription); report.progress.errors += 1; continue }
            let errors = EnumerationErrors()
            guard let enumerator = FileManager.default.enumerator(at: root.url, includingPropertiesForKeys: nil,
                    options: [.skipsPackageDescendants, .skipsHiddenFiles], errorHandler: { url, error in
                        errors.add("\(url.lastPathComponent): \(error.localizedDescription)"); return true
                    }) else {
                report.issues.append("Cannot enumerate \(root.url.lastPathComponent)."); report.progress.errors += 1; continue
            }
            var ancestorsByDirectory = [root.url.path: root.ancestors]
            while let url = enumerator.nextObject() as? URL {
                if Task.isCancelled { report.cancelled = true; break outer }
                if report.progress.visited >= maximumEntries { report.truncated = true; break outer }
                report.progress.visited += 1
                if report.progress.visited % 64 == 0 { await progress(report.progress); await Task.yield() }
                guard !PathPolicy.isProtected(url.path), !settings.excludes(url) else {
                    enumerator.skipDescendants(); report.progress.skipped += 1; continue
                }
                do {
                    let meta = try fileSystem.metadata(url)
                    guard !meta.isSymlink, meta.identity.device == root.identity.device else {
                        enumerator.skipDescendants(); report.progress.skipped += 1; continue
                    }
                    try fileSystem.checkResource(url)
                    if meta.isDirectory {
                        ancestorsByDirectory[url.path] = try fileSystem.ancestors(of: url.appendingPathComponent("scan-check"))
                        continue
                    }
                    let parents = try ancestorsByDirectory[url.deletingLastPathComponent().path]
                        ?? fileSystem.ancestors(of: url)
                    guard meta.isRegular, meta.links == 1, seen.insert(url.path).inserted else { report.progress.skipped += 1; continue }
                    let file = ScannedFile(url: url, root: root, metadata: meta, ancestors: parents)
                    report.files.append(file)
                    if let rule = RuleRegistry.classify(file, settings: settings) {
                        report.candidates.append(Candidate(file: file, rule: rule)); report.progress.candidates += 1
                    }
                } catch {
                    enumerator.skipDescendants(); report.progress.skipped += 1
                    report.progress.errors += 1
                    if report.issues.count < 100 { report.issues.append("\(url.lastPathComponent): \(error.localizedDescription)") }
                }
            }
            let issues = errors.snapshot()
            report.progress.errors += issues.count
            report.issues.append(contentsOf: issues.prefix(max(0, 100 - report.issues.count)))
        }
        report.candidates.sort { $0.size == $1.size ? $0.id < $1.id : $0.size > $1.size }
        report.finished = Date()
        await progress(report.progress)
        return report
    }
}
private final class EnumerationErrors: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    func add(_ value: String) { lock.lock(); defer { lock.unlock() }; if values.count < 100 { values.append(value) } }
    func snapshot() -> [String] { lock.lock(); defer { lock.unlock() }; return values }
}
