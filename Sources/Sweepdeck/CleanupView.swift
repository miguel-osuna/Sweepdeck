import SwiftUI
import SweepdeckCore

struct CleanupView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var sort = CandidateSort.size
    @State private var matchingProgress: CandidateMatchProgress?
    @State private var matchingRequestID = UUID()
    @State private var matchesByRule: [RuleID: [Candidate]] = [:]
    @State private var matchedSearchKey: CleanupSearchKey?
    @State private var pageIndexes: [RuleID: Int] = [:]

    private var searchKey: CleanupSearchKey {
        CleanupSearchKey(query: query, category: model.category, sort: sort, scanStarted: model.report?.started)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageTitle(title: "Smart Cleanup", subtitle: "A suggestion is a starting point. You make the final call.")
            HStack {
                TextField("Filter by name or path", text: $query).textFieldStyle(.roundedBorder)
                Picker("Category", selection: $model.category) {
                    Text("All categories").tag(nil as RuleID?)
                    ForEach(RuleID.allCases) { Text($0.title).tag(Optional($0)) }
                }.frame(width: 250)
                Picker("Sort", selection: $sort) {
                    Text("Size").tag(CandidateSort.size)
                    Text("Name").tag(CandidateSort.name)
                    Text("Oldest").tag(CandidateSort.oldest)
                }.frame(width: 160)
            }
            if model.candidates.isEmpty {
                ContentUnavailableView(model.report == nil ? "Start with a scan" : "No matching candidates", systemImage: "sparkles",
                    description: Text(model.report == nil ? "Choose a folder, then scan it to review eligible files." : "Your settings and safety protections determine what appears here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if matchedSearchKey != searchKey {
                    Group {
                        if let matchingProgress, matchingProgress.total > 0 {
                            ProgressView(
                                "Updating matches: \(matchingProgress.processed.formatted()) of \(matchingProgress.total.formatted())",
                                value: Double(matchingProgress.processed),
                                total: Double(matchingProgress.total)
                            )
                        } else {
                            ProgressView("Updating matching files…")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(RuleID.allCases) { rule in
                                let matches = matchesByRule[rule] ?? []
                                if !matches.isEmpty {
                                    let page = ResultPage(pageIndex: pageIndexes[rule] ?? 0, pageSize: 100, itemCount: matches.count)
                                    let visibleMatches = matches[page.range]
                                    DisclosureGroup {
                                        ForEach(visibleMatches) { candidate in CandidateRow(model: model, candidate: candidate) }
                                        ResultPageFooter(page: page, itemLabel: "files") { pageIndexes[rule] = $0 }
                                    } label: {
                                        HStack {
                                            Label(rule.title, systemImage: rule.symbol).font(.headline)
                                            Text("\(matches.count) files").foregroundStyle(.secondary)
                                            Spacer()
                                            let allSelected = matches.allSatisfy { model.selection.ids.contains($0.id) }
                                            Button(allSelected ? "Deselect all" : "Select all") {
                                                if allSelected { model.selection.ids.subtract(matches.map(\.id)) }
                                                else { model.selection.ids.formUnion(matches.map(\.id)) }
                                            }.buttonStyle(.borderless).disabled(model.isBusy)
                                        }
                                    }.padding(14).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            if matchesByRule.isEmpty { Text("No files match this filter.").foregroundStyle(.secondary).padding() }
                        }
                    }
                }
            }
            if let report = model.report { ScanSummary(report: report) }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(model.selected.count) selected · \(bytes(model.selectedBytes))").font(.headline)
                    Text("All current rules require review. No automatic low-risk selection.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear selection") { model.selection = Selection() }.disabled(model.isBusy || model.selected.isEmpty)
                Button("Preview Cleanup…") { model.preview() }.buttonStyle(.borderedProminent)
                    .disabled(model.isBusy || model.selected.isEmpty || model.persistenceError != nil)
            }
        }
        .task(id: searchKey) {
            let key = searchKey
            let requestID = UUID()
            matchingRequestID = requestID
            let candidates = model.candidates
            matchedSearchKey = nil
            matchingProgress = nil
            let result = await CandidateMatcher.match(
                candidates: candidates,
                query: key.query,
                category: key.category,
                sort: key.sort,
                onProgress: { progress in
                    Task { @MainActor in
                        guard requestID == matchingRequestID, key == searchKey, matchedSearchKey != key else { return }
                        matchingProgress = progress
                    }
                }
            )
            guard !Task.isCancelled, requestID == matchingRequestID else { return }
            matchesByRule = result
            pageIndexes = [:]
            matchingProgress = nil
            matchedSearchKey = key
        }
        .padding(28)
    }
}

private struct CleanupSearchKey: Equatable {
    let query: String
    let category: RuleID?
    let sort: CandidateSort
    let scanStarted: Date?
}

struct CandidateRow: View {
    @ObservedObject var model: AppModel
    let candidate: Candidate
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Toggle(isOn: Binding(get: { model.selection.ids.contains(candidate.id) }, set: { _ in model.selection.toggle(candidate) })) {
                    Text(candidate.url.lastPathComponent).fontWeight(.medium)
                }.toggleStyle(.checkbox).disabled(model.isBusy)
                Spacer()
                Text(bytes(candidate.size)).monospacedDigit()
                Button { expanded.toggle() } label: { Image(systemName: expanded ? "chevron.up" : "info.circle") }
                    .buttonStyle(.borderless).accessibilityLabel("Inspect \(candidate.url.lastPathComponent)")
            }
            Text(candidate.id).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).lineLimit(2)
            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(candidate.rule.reason)
                    LabeledContent("Risk", value: candidate.risk)
                    LabeledContent("Modified", value: candidate.file.metadata.modified.formatted())
                    LabeledContent("Method", value: "Move to macOS Trash")
                    Text("Regeneration: \(candidate.regeneration)").foregroundStyle(.secondary)
                    HStack {
                        Button("Reveal in Finder") { model.reveal(candidate.url) }
                        Button("Exclude this file") { model.exclude(candidate.url) }.disabled(model.isBusy)
                        Button("Exclude parent folder") { model.exclude(candidate.url.deletingLastPathComponent()) }.disabled(model.isBusy)
                    }
                }.font(.callout).padding(.leading, 20)
            }
        }.padding(12).background(.background, in: RoundedRectangle(cornerRadius: 8))
            .contextMenu {
                Button("Reveal in Finder") { model.reveal(candidate.url) }
                Button("Exclude this file") { model.exclude(candidate.url) }.disabled(model.isBusy)
            }
    }
}

struct ConfirmationView: View {
    @ObservedObject var model: AppModel
    let plan: CleanupPlan
    @State private var acknowledged = false
    @State private var readyPageIndex = 0
    @State private var rejectedPageIndex = 0

    private var readyPage: ResultPage {
        ResultPage(pageIndex: readyPageIndex, pageSize: 100, itemCount: plan.ready.count)
    }

    private var rejectedPage: ResultPage {
        ResultPage(pageIndex: rejectedPageIndex, pageSize: 100, itemCount: plan.rejected.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageTitle(title: "Review before moving", subtitle: "Dry run complete. No files have been changed.")
            notice("\(plan.ready.count) files · \(bytes(plan.bytes)) estimated. Files will be moved to Trash, not permanently deleted. Disk space may not increase until you empty Trash yourself.")
            List {
                Section("Ready to move · \(plan.ready.count)") {
                    if plan.ready.isEmpty { Text("No files are ready to move.").foregroundStyle(.secondary) }
                    ForEach(plan.ready[readyPage.range]) { candidate in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text(candidate.url.lastPathComponent).fontWeight(.medium); Spacer(); Text(bytes(candidate.size)) }
                            Text(candidate.id).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            Text("Review Required · Move to Trash").font(.caption).foregroundStyle(.orange)
                        }
                    }
                    ResultPageFooter(page: readyPage, itemLabel: "ready files") { readyPageIndex = $0 }
                }
                if !plan.rejected.isEmpty {
                    Section("Not eligible · \(plan.rejected.count)") {
                        ForEach(plan.rejected[rejectedPage.range]) { item in
                            VStack(alignment: .leading) { Text(item.path).font(.caption); Text("Rejected: \(item.message)").foregroundStyle(.orange) }
                        }
                        ResultPageFooter(page: rejectedPage, itemLabel: "rejected items") { rejectedPageIndex = $0 }
                    }
                }
            }.frame(minHeight: 230)
            Toggle("I reviewed these files and want to move them to Trash.", isOn: $acknowledged)
            Text("Files are validated again at execution. This preview expires after five minutes. Close apps using these files before continuing.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Back to Review", role: .cancel) { model.plan = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Move \(plan.ready.count) Files to Trash", role: .destructive) { model.confirm(plan) }
                    .disabled(!acknowledged || plan.ready.isEmpty).buttonStyle(.borderedProminent)
            }
        }.padding(26).frame(width: 720, height: 590)
    }
}

struct OperationView: View {
    @ObservedObject var model: AppModel
    let operation: OperationRecord
    @State private var pageIndex = 0

    private var page: ResultPage {
        ResultPage(pageIndex: pageIndex, pageSize: 100, itemCount: operation.items.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageTitle(title: "Operation results", subtitle: "\(operation.items.filter { $0.status == .trashed }.count) files moved to Trash. Review every result below.")
            List(operation.items[page.range]) { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.path).textSelection(.enabled)
                    Text("\(item.status.rawValue.capitalized): \(item.message)").font(.caption).foregroundStyle(item.status == .trashed ? Color.secondary : Color.orange)
                    if let path = item.trashPath { Button("Reveal in Trash") { model.reveal(URL(fileURLWithPath: path)) }.buttonStyle(.borderless) }
                }
            }
            ResultPageFooter(page: page, itemLabel: "results") { pageIndex = $0 }
            notice("To restore a file, open Trash in Finder and move it back. Sweepdeck never empties Trash. History retains up to 1,000 recent item results.")
            HStack { Button("Open Trash") { model.revealTrash() }; Spacer(); Button("Done") { model.lastOperation = nil }.keyboardShortcut(.defaultAction) }
        }.padding(26).frame(width: 750, height: 570)
    }
}
