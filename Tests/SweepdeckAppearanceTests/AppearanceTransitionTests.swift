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
    @ObservedObject var effectiveScheme: EffectiveScheme

    var body: some View {
        SchemeProbe(effectiveScheme: effectiveScheme)
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
@Test func switchingFromDarkToSystemRestoresTheWindowScheme() async {
    let application = NSApplication.shared
    let originalApplicationAppearance = application.appearance
    application.appearance = NSAppearance(named: .aqua)

    let selection = AppearanceSelection()
    let effectiveScheme = EffectiveScheme()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
    )
    window.contentView = NSHostingView(rootView: AppearanceHarness(selection: selection, effectiveScheme: effectiveScheme))
    window.orderFrontRegardless()
    defer {
        window.close()
        application.appearance = originalApplicationAppearance
    }

    let darkWasRendered = await waitForScheme(.dark, in: effectiveScheme)
    #expect(darkWasRendered)

    selection.mode = .system
    let systemLightWasRendered = await waitForScheme(.light, in: effectiveScheme)
    #expect(systemLightWasRendered)

    application.appearance = NSAppearance(named: .darkAqua)
    let systemFollowedDarkAppearance = await waitForScheme(.dark, in: effectiveScheme)
    #expect(systemFollowedDarkAppearance)

    selection.mode = .light
    let forcedLightWasRendered = await waitForScheme(.light, in: effectiveScheme)
    #expect(forcedLightWasRendered)

    selection.mode = .system
    let systemDarkWasRendered = await waitForScheme(.dark, in: effectiveScheme)
    #expect(systemDarkWasRendered)

    application.appearance = NSAppearance(named: .aqua)
    let systemFollowedLightAppearance = await waitForScheme(.light, in: effectiveScheme)
    #expect(systemFollowedLightAppearance)
}

@MainActor
private func waitForScheme(_ expected: ColorScheme, in effectiveScheme: EffectiveScheme) async -> Bool {
    for _ in 0..<40 {
        if effectiveScheme.value == expected { return true }
        try? await Task.sleep(for: .milliseconds(25))
    }
    return effectiveScheme.value == expected
}
