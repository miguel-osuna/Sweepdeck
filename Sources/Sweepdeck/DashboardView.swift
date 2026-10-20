import SwiftUI
import SweepdeckCore

struct DashboardView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageTitle(title: "Make space. Keep what matters.", subtitle: "Understand your storage, then decide what goes.")
                HStack(spacing: 20) {
                    ZStack {
                        Circle().stroke(.teal.opacity(0.12), lineWidth: 14)
                        Circle().trim(from: 0, to: model.disk.map { Double($0.used) / Double(max(1, $0.total)) } ?? 0)
                            .stroke(.teal, style: StrokeStyle(lineWidth: 14, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack(spacing: 4) {
                            Image(systemName: "internaldrive").font(.title2).foregroundStyle(.teal)
                            Text(model.disk.map { bytes($0.available) } ?? "—").font(.title2.weight(.semibold))
                            Text("available").font(.caption).foregroundStyle(.secondary)
                        }
                    }.frame(width: 156, height: 156).padding(16)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Available disk space: \(model.disk.map { bytes($0.available) } ?? "unavailable")")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Mac, at a glance").font(.title2.weight(.semibold))
                        if let disk = model.disk {
                            Text("\(bytes(disk.used)) used of \(bytes(disk.total))").foregroundStyle(.secondary)
                        }
                        Text("Scans stay within the folders you choose.\nYou review every file before anything moves to Trash.")
                            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button(model.preferences.roots.isEmpty ? "Choose your first folder" : "Scan authorized folders") {
                                if model.preferences.roots.isEmpty { model.chooseFolder() } else { model.scan() }
                            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.isBusy)
                            Button("Refresh storage") { model.refreshDisk() }.buttonStyle(.borderless)
                        }
                    }
                    Spacer()
                }.padding(16).frame(maxWidth: .infinity).background(.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                if let error = model.diskError { notice(error, color: .orange) }
                HStack(spacing: 14) {
                    MetricCard(title: "Potential cleanup", value: bytes(model.candidates.reduce(0) { $0 + $1.size }), symbol: "sparkles", detail: "Estimated file sizes · review required")
                    MetricCard(title: "Candidates", value: "\(model.candidates.count)", symbol: "doc.on.doc", detail: model.report == nil ? "Run a scan to discover files" : "Nothing selected automatically")
                    MetricCard(title: "Scan locations", value: "\(model.preferences.roots.count)", symbol: "folder", detail: "Explicitly authorized folders")
                }
                HStack {
                    Text("Review opportunities").font(.title3.weight(.semibold))
                    Spacer()
                    if let last = model.lastScan { Text("Last scan \(last.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(RuleID.allCases) { rule in
                        let matches = model.candidates.filter { $0.rule == rule }
                        Button {
                            model.category = rule; model.section = .cleanup
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: rule.symbol).font(.title2).foregroundStyle(.teal).frame(width: 36)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(rule.title).font(.headline)
                                    Text("\(matches.count) files · \(bytes(matches.reduce(0) { $0 + $1.size }))").font(.callout).foregroundStyle(.secondary)
                                    Text("Review Required").font(.caption).foregroundStyle(.orange)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }.padding(18).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                }
                notice("Moving files to Trash does not immediately free disk space. Estimates may differ from storage recovered because of APFS sharing and snapshots.")
                if let report = model.report { ScanSummary(report: report) }
            }.padding(30)
        }
    }
}

struct ScanSummary: View {
    let report: ScanReport
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(report.progress.visited) entries inspected · \(report.progress.skipped) skipped · \(report.progress.errors) issues · \(report.finished.timeIntervalSince(report.started), specifier: "%.1f") seconds")
                .font(.caption).foregroundStyle(.secondary)
            if report.cancelled { notice("Scan cancelled. These are partial results.", color: .orange) }
            if report.truncated { notice("The 25,000-entry limit was reached. Choose a smaller folder for a complete scan.", color: .orange) }
            if !report.issues.isEmpty {
                DisclosureGroup("Scan details (up to 100 issues)") {
                    ForEach(Array(report.issues.enumerated()), id: \.offset) { _, issue in
                        Text(issue).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
