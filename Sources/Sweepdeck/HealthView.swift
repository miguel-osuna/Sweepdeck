import SwiftUI
import SweepdeckCore

struct HealthView: View {
    @ObservedObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var metrics: HealthSnapshot?
    @State private var provider = MetricsProvider()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageTitle(title: "System Health", subtitle: "Useful signals. No magic boosts.")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetricCard(title: "CPU utilization", value: metrics?.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "Sampling…", symbol: "cpu", detail: "System-wide · sampled every 3 seconds")
                    MetricCard(title: "Physical memory", value: metrics.map { bytes(Int64($0.physicalMemory)) } ?? "—", symbol: "memorychip", detail: "Installed RAM")
                    MetricCard(title: "Active, wired + compressed", value: metrics?.usedMemory.map { bytes(Int64($0)) } ?? "Unavailable", symbol: "chart.bar", detail: "Memory estimate · not Activity Monitor's exact total")
                    MetricCard(title: "Swap used", value: metrics?.swapUsed.map { bytes(Int64($0)) } ?? "Unavailable", symbol: "arrow.left.arrow.right", detail: "Current virtual memory on disk")
                    MetricCard(title: "Available disk space", value: model.disk.map { bytes($0.available) } ?? "Unavailable", symbol: "internaldrive", detail: "Home volume · refreshed while this view is active")
                    MetricCard(title: "Thermal state", value: metrics?.thermalState ?? "Unavailable", symbol: "thermometer.medium", detail: "Reported by macOS")
                }
                notice("macOS uses available RAM for useful caching. High memory use alone does not mean your Mac needs cleaning. Sweepdeck never purges RAM, kills processes or deletes swap.")
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Memory pressure & processes").font(.headline)
                        Text("Use Activity Monitor for Apple's memory pressure graph and per-process details. These metrics are not inferred from free RAM.").foregroundStyle(.secondary)
                        Button("Open Activity Monitor") { model.activityMonitor() }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
                Text("Monitoring pauses when you leave this section or the app becomes inactive.").font(.caption).foregroundStyle(.secondary)
            }.padding(28)
        }.task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await provider.reset()
            while !Task.isCancelled {
                metrics = await provider.sample(); model.refreshDisk()
                do { try await Task.sleep(for: .seconds(3)) } catch { break }
            }
        }
    }
}
