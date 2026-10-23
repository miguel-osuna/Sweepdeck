import SwiftUI
import AppKit
import SweepdeckCore

@main
struct SweepdeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model: AppModel
    @StateObject private var updates: UpdateManager

    private var selectedColorScheme: ColorScheme? {
        switch model.preferences.appearanceMode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    @MainActor
    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        _updates = StateObject(wrappedValue: UpdateManager(model: model))
    }

    var body: some Scene {
        Window("Sweepdeck", id: "main") {
            ContentView(model: model, updates: updates)
                .onAppear {
                    delegate.model = model
                    updates.start()
                }
                .frame(minWidth: 940, minHeight: 650)
                .preferredColorScheme(selectedColorScheme)
                .tint(.teal)
        }
        .defaultSize(width: 1180, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Choose Scan Folder…") { model.chooseFolder() }.keyboardShortcut("o").disabled(model.isBusy)
                Button("Scan Authorized Folders") { model.scan() }.keyboardShortcut("r").disabled(model.isBusy || model.preferences.roots.isEmpty)
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .disabled(model.isPresentingPanel || !updates.canCheckForUpdates)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    private var terminationPending = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminationPending {
            return .terminateLater
        }

        guard let model else { return .terminateNow }
        model.discardPendingPreviewForTermination()
        if !model.isBusy {
            return .terminateNow
        } else {
            terminationPending = true
            Task {
                await model.prepareForTermination()
                sender.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        recordTestLaunchIfRequested()
    }

    private func recordTestLaunchIfRequested() {
        guard let markerPath = Bundle.main.object(forInfoDictionaryKey: "SweepdeckTestLaunchMarker") as? String,
              !markerPath.isEmpty else {
            return
        }

        let markerURL = URL(fileURLWithPath: markerPath)
        let launchRecord = "\(ReleaseMetadata.shortVersion(from: Bundle.main.infoDictionary)) \(ProcessInfo.processInfo.processIdentifier)\n"
        do {
            try FileManager.default.createDirectory(
                at: markerURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: markerPath) {
                guard FileManager.default.createFile(atPath: markerPath, contents: nil) else { return }
            }
            let handle = try FileHandle(forWritingTo: markerURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(launchRecord.utf8))
        } catch {
            NSLog("Could not write updater test launch marker: %@", error.localizedDescription)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
