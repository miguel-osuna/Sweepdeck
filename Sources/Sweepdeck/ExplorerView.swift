import SwiftUI
import SweepdeckCore

private struct ExplorerEntry: Identifiable {
    let url: URL
    let size: Int64
    let count: Int
    let directory: Bool
    var id: String { url.path }
}
struct ExplorerView: View {
    @ObservedObject var model: AppModel
    @State private var location: URL?
    @State private var type = ""
    @State private var minimumMB = 0
    @State private var onlyOld = false
    private var entries: [ExplorerEntry] {
        let files = (model.report?.files ?? []).filter {
            (type.isEmpty || $0.url.pathExtension.localizedCaseInsensitiveContains(type)) &&
            $0.metadata.size >= Int64(minimumMB) * 1_000_000 &&
            (!onlyOld || Date().timeIntervalSince($0.metadata.modified) >= Double(model.preferences.boundedAgeDays) * 86400)
        }
        guard let location else {
            return model.preferences.roots.map { root in
                let children = files.filter { PathPolicy.contains($0.id, in: root.url.path) }
                return ExplorerEntry(url: root.url, size: children.reduce(0) { $0 + $1.metadata.size }, count: children.count, directory: true)
            }.sorted { $0.size > $1.size }
        }
        var groups: [String: [ScannedFile]] = [:]
        for file in files where PathPolicy.contains(file.id, in: location.path) {
            let suffix = file.id.dropFirst(location.path.count).split(separator: "/")
            if let first = suffix.first { groups[String(first), default: []].append(file) }
        }
        return groups.map { name, children in
            let url = location.appendingPathComponent(name)
            return ExplorerEntry(url: url, size: children.reduce(0) { $0 + $1.metadata.size }, count: children.count,
                                 directory: children.count != 1 || children[0].url.path != url.path)
        }.sorted { $0.size == $1.size ? $0.id < $1.id : $0.size > $1.size }
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
    }
}
