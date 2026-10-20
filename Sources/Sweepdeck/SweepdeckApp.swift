import SwiftUI
import AppKit

@main
struct SweepdeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("Sweepdeck", id: "main") {
            ContentView(model: model)
                .onAppear { delegate.model=model }
                .frame(minWidth: 940, minHeight: 650)
                .preferredColorScheme(model.preferences.appearance == "Dark" ? .dark : model.preferences.appearance == "Light" ? .light : nil)
                .tint(.teal)
        }
        .defaultSize(width: 1180, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Choose Scan Folder…") { model.chooseFolder() }.keyboardShortcut("o").disabled(model.isBusy)
                Button("Scan Authorized Folders") { model.scan() }.keyboardShortcut("r").disabled(model.isBusy || model.preferences.roots.isEmpty)
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

        if model == nil || !model!.isBusy {
            return .terminateNow
        } else {
            terminationPending = true
            Task {
                await model?.prepareForTermination()
                sender.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
