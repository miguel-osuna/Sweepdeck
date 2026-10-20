import SwiftUI
import SweepdeckCore

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageTitle(title: "Settings", subtitle: "Set the boundaries. Sweepdeck works inside them.")
                GroupBox("Authorized scan folders") {
                    VStack(alignment: .leading, spacing: 12) {
                        if model.preferences.roots.isEmpty { Text("No folders authorized yet.").foregroundStyle(.secondary) }
                        ForEach(model.preferences.roots) { root in
                            HStack {
                                Label(root.url.path, systemImage: "folder").textSelection(.enabled)
                                Spacer()
                                Button("Remove") { model.preferences.roots.removeAll { $0.id == root.id } }
                            }
                        }
                        Button("Add Folder…") { model.chooseFolder() }
                        Text("Only internal, local folders are supported in this release. Repositories, Library data and system paths remain protected.").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }.disabled(model.isBusy)
                GroupBox("Scan rules") {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(RuleID.allCases) { rule in
                            Toggle(rule.title, isOn: Binding(get: { model.preferences.enabledRules.contains(rule) }, set: { value in
                                if value { model.preferences.enabledRules.insert(rule) } else { model.preferences.enabledRules.remove(rule) }
                            }))
                        }
                        Stepper("Older than \(model.preferences.ageDays) days", value: $model.preferences.ageDays, in: 1...3650, step: 1)
                        Stepper("Large files: \(model.preferences.minimumLargeMB) MB or more", value: $model.preferences.minimumLargeMB, in: 1...100000, step: 50)
                        Text("Rule and exclusion changes clear previous scan results. Age and size never prove that a file is unnecessary.").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }.disabled(model.isBusy)
                GroupBox("Excluded files and folders") {
                    VStack(alignment: .leading, spacing: 12) {
                        if model.preferences.excludedPaths.isEmpty { Text("No custom exclusions.").foregroundStyle(.secondary) }
                        ForEach(model.preferences.excludedPaths, id: \.self) { path in
                            HStack {
                                Text(path).textSelection(.enabled)
                                Spacer()
                                Button("Remove") { model.preferences.excludedPaths.removeAll { $0 == path } }
                            }
                        }
                        Button("Add Exclusion…") { model.chooseFolder(exclusion: true) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }.disabled(model.isBusy)
                GroupBox("Appearance and safety") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Appearance", selection: $model.preferences.appearance) {
                            Text("System").tag("System"); Text("Light").tag("Light"); Text("Dark").tag("Dark")
                        }.pickerStyle(.segmented)
                        Label("Trash only · confirmation always required", systemImage: "lock.shield")
                        Text("Permanent deletion, automatic selection, external-volume scans and background indexing are unavailable by design in this MVP.").font(.caption).foregroundStyle(.secondary)
                    }.padding(10)
                }
                GroupBox("Operation history") {
                    VStack(alignment: .leading, spacing: 12) {
                        if model.history.isEmpty { Text("No cleanup operations yet.").foregroundStyle(.secondary) }
                        ForEach(model.history) { record in
                            HStack {
                                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                Text("\(record.items.filter { $0.status == .trashed }.count) moved · \(record.items.count) retained results").foregroundStyle(.secondary)
                                Spacer()
                                Button("Details") { model.lastOperation = record }
                            }
                        }
                        Text("Local only. Retains at most 50 operations and 1,000 item results; older detail is pruned.").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text("Sweepdeck 0.1.0 (1)").font(.headline)
                        Text("Original MIT-licensed code · Apple frameworks · no telemetry").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Export Diagnostics…") { model.exportDiagnostics() }
                }
            }.padding(28)
        }
    }
}
