import SwiftUI
import SweepdeckCore

struct ContentView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.up.fill").font(.title).foregroundStyle(.teal)
                    VStack(alignment: .leading) {
                        Text("Sweepdeck").font(.title3.weight(.semibold))
                        Text("A little room to breathe.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 16).padding(.top, 20)
                List(SectionID.allCases, selection: $model.section) { section in
                    Label(section.rawValue, systemImage: section.symbol).tag(section).padding(.vertical, 6)
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Local. Private. In your control.", systemImage: "lock.shield").font(.caption)
                    Text("No background scans. No automatic cleanup.").font(.caption2).foregroundStyle(.secondary)
                    Text("Version 0.1.0 · MVP").font(.caption2).foregroundStyle(.tertiary)
                }.padding(16)
            }.navigationSplitViewColumnWidth(min: 220, ideal: 235, max: 260)
        } detail: {
            VStack(spacing: 0) {
                if let problem = model.persistenceError { notice(problem, symbol: "exclamationmark.shield", color: .orange).padding() }
                if let busy = model.busyOperation {
                    HStack {
                        switch busy {
                        case .scanning:
                            ProgressView().controlSize(.small)
                            Text(busy.title)
                            Text("\(model.progress.visited) entries inspected")
                                .foregroundStyle(.secondary)
                        case .cleanup:
                            if model.cleanupProgress.total > 0 {
                                ProgressView(value: Double(model.cleanupProgress.completed), total: Double(model.cleanupProgress.total))
                                    .frame(width: 110)
                                    .accessibilityLabel(busy.title)
                            } else {
                                ProgressView().controlSize(.small)
                            }
                            Text("\(model.cleanupProgress.completed) of \(model.cleanupProgress.total) items handled")
                                .foregroundStyle(.secondary)
                        case .validating:
                            ProgressView().controlSize(.small)
                            Text(busy.title)
                        }
                        Spacer()
                        Button("Cancel") { model.cancel() }
                    }.padding().background(.teal.opacity(0.08))
                }
                Group {
                    switch model.section ?? .dashboard {
                    case .dashboard: DashboardView(model: model)
                    case .cleanup: CleanupView(model: model)
                    case .explorer: ExplorerView(model: model)
                    case .health: HealthView(model: model)
                    case .settings: PreferencesView(model: model)
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button { model.chooseFolder() } label: { Label("Choose Folder", systemImage: "folder.badge.plus") }
                        .disabled(model.isBusy)
                    Button { model.scan() } label: { Label("Scan Mac", systemImage: "magnifyingglass") }
                        .disabled(model.isBusy || model.preferences.roots.isEmpty)
                        .help("Scan only your authorized folders")
                }
            }
        }
        .sheet(item: $model.plan) { plan in ConfirmationView(model: model, plan: plan) }
        .sheet(item: $model.lastOperation) { operation in OperationView(model: model, operation: operation) }
        .alert("Sweepdeck", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

func notice(_ text: String, symbol: String = "info.circle", color: Color = .teal) -> some View {
    Label(text, systemImage: symbol).font(.callout).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
}

struct PageTitle: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.largeTitle.weight(.semibold))
            Text(subtitle).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ResultPageFooter: View {
    let page: ResultPage
    let itemLabel: String
    let onPageChange: (Int) -> Void

    var body: some View {
        if page.pageCount > 1 {
            HStack {
                Text("Showing \(page.range.lowerBound + 1)–\(page.range.upperBound) of \(page.itemCount) \(itemLabel)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Button("Previous") { onPageChange(page.pageIndex - 1) }
                    .disabled(!page.hasPrevious)
                Text("Page \(page.pageIndex + 1) of \(page.pageCount)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                Button("Next") { onPageChange(page.pageIndex + 1) }
                    .disabled(!page.hasNext)
            }
            .buttonStyle(.borderless)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    var detail: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.callout).foregroundStyle(.secondary)
            Text(value).font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
            if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
    }
}
