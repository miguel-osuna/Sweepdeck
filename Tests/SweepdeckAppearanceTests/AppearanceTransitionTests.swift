import AppKit
import Combine
import SwiftUI
import Testing
import SweepdeckAppearance
import SweepdeckCore

@MainActor
private final class AppearanceSelection: ObservableObject {
    @Published var mode: AppearanceMode = .dark
}

@MainActor
private final class EffectiveScheme: ObservableObject {
    @Published var value: ColorScheme?
}

private struct AppearanceHarness: View {
    @ObservedObject var selection: AppearanceSelection
    @ObservedObject var sidebarScheme: EffectiveScheme
    @ObservedObject var detailScheme: EffectiveScheme

    var body: some View {
        NavigationSplitView {
            List {
                SchemeProbe(effectiveScheme: sidebarScheme)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.sidebar)
        } detail: {
            ScrollView {
                VStack(alignment: .leading) {
                    SchemeProbe(effectiveScheme: detailScheme)
                    GroupBox("Appearance and safety") {
                        Text("Trash only · confirmation always required")
                    }
                }
                .padding()
            }
            .background(.background)
        }
            .sweepdeckAppearance(selection.mode)
    }
}

private struct SchemeProbe: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var effectiveScheme: EffectiveScheme

    var body: some View {
        Text(colorScheme == .dark ? "Dark" : "Light")
            .onAppear { effectiveScheme.value = colorScheme }
            .onChange(of: colorScheme) { _, value in effectiveScheme.value = value }
    }
}

@MainActor
@Test func switchingFromDarkToSystemKeepsSplitViewInSystemAppearance() async {
    let application = NSApplication.shared
    let originalApplicationAppearance = application.appearance
    application.appearance = NSAppearance(named: .aqua)

    let selection = AppearanceSelection()
    let sidebarScheme = EffectiveScheme()
    let detailScheme = EffectiveScheme()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
    )
    // Keep the hosted window offscreen so this scheme regression remains headless in CI.
    window.contentView = NSHostingView(rootView: AppearanceHarness(
        selection: selection,
        sidebarScheme: sidebarScheme,
        detailScheme: detailScheme
    ))
    defer {
        window.close()
        application.appearance = originalApplicationAppearance
    }

    let darkSidebarWasRendered = await waitForScheme(.dark, in: sidebarScheme)
    let darkDetailWasRendered = await waitForScheme(.dark, in: detailScheme)
    #expect(darkSidebarWasRendered)
    #expect(darkDetailWasRendered)
    #expect(window.appearance?.name == .darkAqua)
    #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)

    selection.mode = .system
    let systemLightSidebarWasRendered = await waitForScheme(.light, in: sidebarScheme)
    let systemLightDetailWasRendered = await waitForScheme(.light, in: detailScheme)
    #expect(systemLightSidebarWasRendered)
    #expect(systemLightDetailWasRendered)
    #expect(window.appearance == nil)
    #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua)

    application.appearance = NSAppearance(named: .darkAqua)
    let systemSidebarFollowedDarkAppearance = await waitForScheme(.dark, in: sidebarScheme)
    let systemDetailFollowedDarkAppearance = await waitForScheme(.dark, in: detailScheme)
    #expect(systemSidebarFollowedDarkAppearance)
    #expect(systemDetailFollowedDarkAppearance)

    selection.mode = .light
    let forcedLightSidebarWasRendered = await waitForScheme(.light, in: sidebarScheme)
    let forcedLightDetailWasRendered = await waitForScheme(.light, in: detailScheme)
    #expect(forcedLightSidebarWasRendered)
    #expect(forcedLightDetailWasRendered)
    #expect(window.appearance?.name == .aqua)
    #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua)

    selection.mode = .system
    let systemDarkSidebarWasRendered = await waitForScheme(.dark, in: sidebarScheme)
    let systemDarkDetailWasRendered = await waitForScheme(.dark, in: detailScheme)
    #expect(systemDarkSidebarWasRendered)
    #expect(systemDarkDetailWasRendered)
    #expect(window.appearance == nil)
    #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)

    application.appearance = NSAppearance(named: .aqua)
    let systemSidebarFollowedLightAppearance = await waitForScheme(.light, in: sidebarScheme)
    let systemDetailFollowedLightAppearance = await waitForScheme(.light, in: detailScheme)
    #expect(systemSidebarFollowedLightAppearance)
    #expect(systemDetailFollowedLightAppearance)
}

@MainActor
private func waitForScheme(_ expected: ColorScheme, in effectiveScheme: EffectiveScheme) async -> Bool {
    for _ in 0..<40 {
        if effectiveScheme.value == expected { return true }
        try? await Task.sleep(for: .milliseconds(25))
    }
    return effectiveScheme.value == expected
}
