import AppKit
import SwiftUI
import SweepdeckCore

public extension View {
    func sweepdeckAppearance(_ mode: AppearanceMode) -> some View {
        background(WindowAppearanceBridge(mode: mode)
            .allowsHitTesting(false)
            .accessibilityHidden(true))
    }
}

private struct WindowAppearanceBridge: NSViewRepresentable {
    let mode: AppearanceMode

    func makeNSView(context: Context) -> WindowAppearanceAnchor {
        let view = WindowAppearanceAnchor()
        view.mode = mode
        return view
    }

    func updateNSView(_ view: WindowAppearanceAnchor, context: Context) {
        view.mode = mode
    }
}

@MainActor
private final class WindowAppearanceAnchor: NSView {
    var mode: AppearanceMode = .system {
        didSet { applyAppearance() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyAppearance()
    }

    private func applyAppearance() {
        guard let window else { return }
        let requestedAppearance: NSAppearance?
        switch mode {
        case .system: requestedAppearance = nil
        case .light: requestedAppearance = NSAppearance(named: .aqua)
        case .dark: requestedAppearance = NSAppearance(named: .darkAqua)
        }
        guard window.appearance?.name != requestedAppearance?.name else { return }
        window.appearance = requestedAppearance
    }
}
