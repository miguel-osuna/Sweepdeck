import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import SweepdeckCore

enum SectionID: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard", cleanup = "Smart Cleanup", explorer = "Disk Explorer", health = "System Health", settings = "Settings"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .cleanup: "sparkles"
        case .explorer: "internaldrive"
        case .health: "waveform.path.ecg"
        case .settings: "slider.horizontal.3"
        }
    }
}

enum BusyOperation: Sendable {
    case scanning, validating, cleanup

    var title: String {
        switch self {
        case .scanning: "Scanning authorized folders"
        case .validating: "Validating selection"
        case .cleanup: "Moving confirmed files to Trash"
        }
    }
}

struct CleanupProgress: Equatable, Sendable {
    var completed = 0
    let total: Int

    init(completed: Int = 0, total: Int = 0) {
        self.completed = completed
        self.total = total
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var section: SectionID? = .dashboard
    @Published var preferences: Preferences {
        didSet {
            guard initialized else { return }
            state.preferences = preferences
            save()
            if oldValue.roots != preferences.roots || oldValue.excludedPaths != preferences.excludedPaths ||
                oldValue.ageDays != preferences.ageDays || oldValue.minimumLargeMB != preferences.minimumLargeMB ||
                oldValue.enabledRules != preferences.enabledRules {
                report = nil; selection = Selection(); plan = nil
            }
        }
    }
    @Published var report: ScanReport? {
        didSet { candidateIndex = CandidateIndex(report?.candidates ?? []) }
    }
    private(set) var candidateIndex = CandidateIndex([])
    @Published var selection = Selection()
    @Published var progress = ScanProgress()
    @Published var busyOperation: BusyOperation?
    @Published private(set) var cleanupProgress = CleanupProgress()
    @Published var disk: DiskSnapshot?
    @Published var diskError: String?
    @Published var plan: CleanupPlan?
    @Published var lastOperation: OperationRecord?
    @Published var history: [OperationRecord]
    @Published var lastScan: Date?
    @Published var errorMessage: String?
    @Published var persistenceError: String?
    @Published var category: RuleID?
    private var state: SavedState
    private let store: JSONStore
    private let scanner = FolderScanner()
    private let executor = CleanupExecutor()
    private var task: Task<Void, Never>?
    private var initialized = false
    @Published private(set) var isPresentingPanel = false

    init() {
        if let directory = ProcessInfo.processInfo.environment["SWEEPDECK_STATE_DIR"] {
            store = JSONStore(url: URL(fileURLWithPath: directory).appendingPathComponent("state.json"))
        } else { store = .application }
        do { state = try store.load() }
        catch { state = SavedState(); persistenceError = "Preferences could not be loaded. Cleanup and saving are disabled to preserve your existing file. \(error.localizedDescription)" }
        preferences = state.preferences; history = state.history; lastScan = state.lastScan
        initialized = true
        refreshDisk()
    }
    @Published private(set) var isTerminating=false
    var isBusy: Bool { busyOperation != nil || isTerminating || isPresentingPanel }
    private var panelWindow: NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible })
    }
    var candidates: [Candidate] { report?.candidates ?? [] }
    var selected: [Candidate] { candidates.filter { selection.ids.contains($0.id) } }
    var selectedBytes: Int64 { selection.bytes(in: candidates) }
    func save() {
        guard persistenceError == nil else { return }
        do { try store.save(state) }
        catch { persistenceError = "Could not save preferences. Cleanup is disabled. \(error.localizedDescription)" }
    }
    func refreshDisk() {
        do { disk = try DiskSnapshot.read(); diskError = nil }
        catch { diskError = error.localizedDescription }
    }
    func chooseFolder(exclusion: Bool = false) {
        guard !isBusy else { return }
        isPresentingPanel = true
        let panel = NSOpenPanel()
        panel.canChooseFiles = exclusion
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = exclusion ? "Exclude" : "Authorize Folder"
        panel.message = exclusion ? "This item and its descendants will be excluded." : "Sweepdeck will scan only folders you authorize. Nothing is selected for cleanup automatically."

        guard let window = panelWindow else {
            errorMessage = "Could not find a window to present the panel."
            isPresentingPanel = false
            return
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.isPresentingPanel = false

            guard response == .OK, let url = panel.url else { return }

            if exclusion {
                self.exclude(url)
                return
            }

            do {
                let root = try LocalFileSystem().authorize(url)
                self.preferences.roots.removeAll { $0.id == root.id }
                self.preferences.roots.append(root)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    func exclude(_ url: URL) {
        guard !preferences.excludedPaths.contains(url.path) else { return }
        preferences.excludedPaths.append(url.path)
    }
    func scan() {
        guard !isBusy, !preferences.roots.isEmpty else { return }
        selection = Selection(); report = nil; plan = nil; progress = ScanProgress()
        cleanupProgress = CleanupProgress()
        busyOperation = .scanning
        let settings = preferences
        task = Task {
            let result = await scanner.scan(roots: settings.roots, settings: settings) { value in
                await MainActor.run { self.progress = value }
            }
            report = result; busyOperation = nil; task = nil
            lastScan = result.finished; state.lastScan = lastScan; save(); refreshDisk()
        }
    }
    func cancel() { task?.cancel() }
    func prepareForTermination() async {
        isTerminating=true
        let pending=task
        pending?.cancel()
        await pending?.value
    }
    func preview() {
        guard !isBusy, !selected.isEmpty, persistenceError == nil else { return }
        let items = selected, settings = preferences
        busyOperation = .validating
        task = Task {
            let preview = await executor.preview(items, roots: settings.roots, settings: settings)
            if !Task.isCancelled { plan = preview }
            busyOperation = nil; task = nil
        }
    }
    func confirm(_ confirmedPlan: CleanupPlan) {
        guard !isBusy, persistenceError == nil, plan?.id == confirmedPlan.id else { return }
        plan = nil; busyOperation = .cleanup
        cleanupProgress = CleanupProgress(total: confirmedPlan.ready.count)
        let settings = preferences
        task = Task {
            let result = await executor.execute(confirmedPlan, roots: settings.roots, settings: settings, confirmed: true) { count in
                await MainActor.run {
                    self.cleanupProgress = CleanupProgress(completed: count, total: self.cleanupProgress.total)
                }
            }
            state.record(result); history = state.history; save()
            lastOperation = result; selection = Selection(); report = nil
            busyOperation = nil; task = nil; refreshDisk()
        }
    }
    func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    func revealTrash() { NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash")) }
    func activityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }
    func exportDiagnostics() {
        guard !isBusy else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Sweepdeck-diagnostics.json"
        isPresentingPanel = true
        guard let window = panelWindow else {
            isPresentingPanel = false
            errorMessage = "Could not find a window to present the panel."
            return
        }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.isPresentingPanel = false
            guard response == .OK, let url = panel.url else { return }
            let data: [String: String] = [
                "version": ReleaseMetadata.shortVersion(from: Bundle.main.infoDictionary), "system": ProcessInfo.processInfo.operatingSystemVersionString,
                "authorizedFolderCount": String(self.preferences.roots.count), "exclusionCount": String(self.preferences.excludedPaths.count),
                "lastScanFiles": String(self.report?.progress.visited ?? 0), "lastScanErrors": String(self.report?.progress.errors ?? 0),
                "historyOperations": String(self.history.count), "privacy": "No filenames, paths, file contents or credentials included."
            ]
            do {
                try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

func bytes(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
