import SwiftUI
import SweepdeckCore

struct ExplorerView: View {
    @ObservedObject var model: AppModel
    @State private var location: URL?
    @State private var type = ""
    @State private var minimumMB = 0
    @State private var onlyOld = false
    @State private var entries: [DiskExplorerEntry] = []
    @State private var matchingProgress: ExplorerMatchProgress?
    @State private var matchedSearchKey: ExplorerSearchKey?

    private var searchKey: ExplorerSearchKey {
        ExplorerSearchKey(
            scanStarted: model.report?.started,
            locationPath: location?.path,
            extensionFilter: type,
            minimumMB: minimumMB,
            onlyOld: onlyOld,
            ageDays: model.preferences.boundedAgeDays,
            rootPaths: model.preferences.roots.map(\.url.path)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageTitle(title: "Disk Explorer", subtitle: "Follow the space in your most recent scan.")
            notice("Shows eligible files from authorized folders only. Protected, inaccessible and skipped items are not included. Folder totals are partial logical sizes.")
            HStack {
                Button { location = nil } label: { Label("Scan roots", systemImage: "house") }
                if let current = location {
                    Button { location = model.preferences.roots.contains(where: { $0.url == current }) ? nil : current.deletingLastPathComponent() } label: { Image(systemName: "arrow.up") }
                        .accessibilityLabel("Parent folder")
                    Text(current.path).font(.caption).textSelection(.enabled).lineLimit(2)
                }
                Spacer()
            }
            HStack {
                TextField("File extension", text: $type).textFieldStyle(.roundedBorder).frame(width: 160)
                Picker("Minimum size", selection: $minimumMB) {
                    Text("Any size").tag(0); Text("10 MB").tag(10); Text("100 MB").tag(100); Text("1 GB").tag(1000)
                }.frame(width: 240)
                Toggle("Older than \(model.preferences.boundedAgeDays) days", isOn: $onlyOld)
            }
            if model.report == nil {
                ContentUnavailableView("Scan a folder to explore it", systemImage: "folder", description: Text("The explorer reuses scan results without background indexing.")).frame(maxHeight: .infinity)
            } else if matchedSearchKey != searchKey {
                if let matchingProgress, matchingProgress.total > 0 {
                    ProgressView(
                        "Updating explorer: \(matchingProgress.processed.formatted()) of \(matchingProgress.total.formatted()) files",
                        value: Double(matchingProgress.processed),
                        total: Double(matchingProgress.total)
                    ).frame(maxHeight: .infinity)
                } else {
                    ProgressView("Updating disk explorer…").frame(maxHeight: .infinity)
                }
            } else if entries.isEmpty {
                ContentUnavailableView("No files match these filters", systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try a different extension, size threshold, or age filter.")).frame(maxHeight: .infinity)
            } else {
                List(entries) { entry in
                    HStack(spacing: 14) {
                        Image(systemName: entry.directory ? "folder.fill" : "doc").foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 4) {
                            if entry.directory { Button(entry.url.lastPathComponent) { location = entry.url }.buttonStyle(.plain).fontWeight(.medium) }
                            else { Text(entry.url.lastPathComponent).fontWeight(.medium) }
                            Text(entry.directory ? "\(entry.count) eligible files" : entry.url.pathExtension.uppercased()).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(bytes(entry.size)).monospacedDigit()
                        Button("Reveal") { model.reveal(entry.url) }.buttonStyle(.borderless)
                        if let candidate = model.candidateIndex.candidate(atPath: entry.id) {
                            Button(model.selection.ids.contains(candidate.id) ? "Deselect" : "Select for review") { model.selection.toggle(candidate) }
                                .disabled(model.isBusy)
                        }
                        if entry.directory { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                    }.padding(.vertical, 7)
                }.listStyle(.inset)
            }
            HStack {
                Text("Largest first · rescan after files change").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Review selected files (\(model.selected.count))") { model.section = .cleanup; model.category = nil }
            }
        }.padding(28)
        .onChange(of: model.report?.started) { location = nil }
        .task(id: searchKey) {
            let key = searchKey
            guard let report = model.report else {
                entries = []
                matchingProgress = nil
                matchedSearchKey = key
                return
            }

            matchedSearchKey = nil
            matchingProgress = nil
            let roots = model.preferences.roots
            let location = self.location
            let modifiedBefore = key.onlyOld
                ? Date().addingTimeInterval(-Double(key.ageDays) * 86_400)
                : nil
            let result = await DiskExplorerMatcher.entries(
                files: report.files,
                roots: roots,
                location: location,
                extensionFilter: key.extensionFilter,
                minimumBytes: Int64(key.minimumMB) * 1_000_000,
                modifiedBefore: modifiedBefore
            ) { progress in
                Task { @MainActor in
                    guard key == searchKey, matchedSearchKey != key else { return }
                    if progress.processed >= (matchingProgress?.processed ?? 0) {
                        matchingProgress = progress
                    }
                }
            }
            guard !Task.isCancelled, key == searchKey else { return }
            entries = result
            matchingProgress = nil
            matchedSearchKey = key
        }
    }
}

private struct ExplorerSearchKey: Equatable {
    let scanStarted: Date?
    let locationPath: String?
    let extensionFilter: String
    let minimumMB: Int
    let onlyOld: Bool
    let ageDays: Int
    let rootPaths: [String]
}
