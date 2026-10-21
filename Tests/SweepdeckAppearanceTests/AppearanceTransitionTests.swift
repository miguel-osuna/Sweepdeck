import AppKit
import Combine
import SwiftUI
import SweepdeckAppearance
import SweepdeckCore
#if SWEEPDECK_USE_XCTEST && canImport(XCTest)
import XCTest
#else
import Testing
#endif

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
private func verifyDarkToSystemAppearanceTransition() async throws {
    let application = NSApplication.shared
    let originalApplicationAppearance = application.appearance
    application.appearance = NSAppearance(named: .aqua)

    let selection = AppearanceSelection()
    let sidebarScheme = EffectiveScheme()
    let detailScheme = EffectiveScheme()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1_200, height: 800),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
    )
    // Keep the hosted window offscreen so this scheme regression remains headless in CI.
    let hostingView = NSHostingView(rootView: AppearanceHarness(
        selection: selection,
        sidebarScheme: sidebarScheme,
        detailScheme: detailScheme
    ))
    window.contentView = hostingView
    defer {
        window.close()
        application.appearance = originalApplicationAppearance
    }

    let darkSidebarWasRendered = await waitForScheme(.dark, in: sidebarScheme)
    let darkDetailWasRendered = await waitForScheme(.dark, in: detailScheme)
    try expect(darkSidebarWasRendered, "The sidebar did not render dark appearance.")
    try expect(darkDetailWasRendered, "The detail view did not render dark appearance.")
    try expect(window.appearance?.name == .darkAqua, "Dark mode was not applied to the window.")
    try expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua, "The window did not resolve to dark appearance.")
    let darkImage = captureRenderedImage(of: hostingView)
    try expect(darkImage != nil, "The dark appearance view did not render an image.")

    selection.mode = .system
    let systemLightSidebarWasRendered = await waitForScheme(.light, in: sidebarScheme)
    let systemLightDetailWasRendered = await waitForScheme(.light, in: detailScheme)
    try expect(systemLightSidebarWasRendered, "The sidebar did not follow System light appearance.")
    try expect(systemLightDetailWasRendered, "The detail view did not follow System light appearance.")
    try expect(window.appearance == nil, "System appearance should clear the forced window appearance.")
    try expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua, "The window did not resolve to System light appearance.")
    let systemLightImage = captureRenderedImage(of: hostingView)
    try expect(systemLightImage != nil, "The System light view did not render an image.")

    application.appearance = NSAppearance(named: .darkAqua)
    let systemSidebarFollowedDarkAppearance = await waitForScheme(.dark, in: sidebarScheme)
    let systemDetailFollowedDarkAppearance = await waitForScheme(.dark, in: detailScheme)
    try expect(systemSidebarFollowedDarkAppearance, "The sidebar did not follow System dark appearance.")
    try expect(systemDetailFollowedDarkAppearance, "The detail view did not follow System dark appearance.")

    selection.mode = .light
    let forcedLightSidebarWasRendered = await waitForScheme(.light, in: sidebarScheme)
    let forcedLightDetailWasRendered = await waitForScheme(.light, in: detailScheme)
    try expect(forcedLightSidebarWasRendered, "The sidebar did not render forced light appearance.")
    try expect(forcedLightDetailWasRendered, "The detail view did not render forced light appearance.")
    try expect(window.appearance?.name == .aqua, "Light mode was not applied to the window.")
    try expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua, "The window did not resolve to forced light appearance.")
    let forcedLightImage = captureRenderedImage(of: hostingView)
    try expect(forcedLightImage != nil, "The forced light view did not render an image.")

    selection.mode = .system
    let systemDarkSidebarWasRendered = await waitForScheme(.dark, in: sidebarScheme)
    let systemDarkDetailWasRendered = await waitForScheme(.dark, in: detailScheme)
    try expect(systemDarkSidebarWasRendered, "The sidebar did not follow System dark appearance after forced light mode.")
    try expect(systemDarkDetailWasRendered, "The detail view did not follow System dark appearance after forced light mode.")
    try expect(window.appearance == nil, "System appearance should clear the forced window appearance after light mode.")
    try expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua, "The window did not resolve to System dark appearance after forced light mode.")

    application.appearance = NSAppearance(named: .aqua)
    let systemSidebarFollowedLightAppearance = await waitForScheme(.light, in: sidebarScheme)
    let systemDetailFollowedLightAppearance = await waitForScheme(.light, in: detailScheme)
    try expect(systemSidebarFollowedLightAppearance, "The sidebar did not follow System light appearance after dark mode.")
    try expect(systemDetailFollowedLightAppearance, "The detail view did not follow System light appearance after dark mode.")

    guard let darkImage, let systemLightImage, let forcedLightImage else {
        throw AppearanceRegressionFailure(description: "A view image could not be captured for appearance comparison.")
    }
    try expect(darkImage.pixelsWide > 0, "The dark image has no width.")
    try expect(darkImage.pixelsHigh > 0, "The dark image has no height.")
    try expect(renderedDifferenceCount(darkImage, forcedLightImage) > 0, "Dark and forced light renders were identical.")
    try expect(renderedDifferenceCount(systemLightImage, forcedLightImage) == 0, "System light and forced light renders differed.")
}

private struct AppearanceRegressionFailure: Error, CustomStringConvertible {
    let description: String
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw AppearanceRegressionFailure(description: message) }
}

#if SWEEPDECK_USE_XCTEST && canImport(XCTest)
final class AppearanceTransitionTests: XCTestCase {
    @MainActor
    func test_switchingFromDarkToSystemKeepsSplitViewInSystemAppearance() async {
        do {
            try await verifyDarkToSystemAppearanceTransition()
        } catch {
            XCTFail(String(describing: error))
        }
    }
}
#else
@MainActor
@Test func switchingFromDarkToSystemKeepsSplitViewInSystemAppearance() async throws {
    try await verifyDarkToSystemAppearanceTransition()
}
#endif

@MainActor
private func captureRenderedImage(of view: NSView) -> NSBitmapImageRep? {
    view.layoutSubtreeIfNeeded()
    guard let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    view.cacheDisplay(in: view.bounds, to: image)
    return image
}

@MainActor
private func renderedDifferenceCount(_ left: NSBitmapImageRep, _ right: NSBitmapImageRep) -> Int {
    guard left.pixelsWide == right.pixelsWide, left.pixelsHigh == right.pixelsHigh else { return .max }
    var differences = 0
    // Sample the full rendered surface on a coarse grid. Converting every
    // AppKit pixel to device RGB made this regression test take tens of seconds.
    for y in stride(from: 0, to: left.pixelsHigh, by: 8) {
        for x in stride(from: 0, to: left.pixelsWide, by: 8) {
            guard let leftPixel = left.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                  let rightPixel = right.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                differences += 1
                continue
            }
            if abs(leftPixel.redComponent - rightPixel.redComponent) > 0.001
                || abs(leftPixel.greenComponent - rightPixel.greenComponent) > 0.001
                || abs(leftPixel.blueComponent - rightPixel.blueComponent) > 0.001
                || abs(leftPixel.alphaComponent - rightPixel.alphaComponent) > 0.001 {
                differences += 1
            }
        }
    }
    return differences
}

@MainActor
private func waitForScheme(_ expected: ColorScheme, in effectiveScheme: EffectiveScheme) async -> Bool {
    for _ in 0..<40 {
        if effectiveScheme.value == expected { return true }
        try? await Task.sleep(for: .milliseconds(25))
    }
    return effectiveScheme.value == expected
}
