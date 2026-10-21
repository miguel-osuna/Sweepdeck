import AppKit
import Combine
import SwiftUI
import SweepdeckPresentation
import Testing

@MainActor
private final class StatusFrameProbe: ObservableObject {
    @Published var frame: CGRect?
}

@MainActor
private final class StatusPlacementSelection: ObservableObject {
    @Published var value = ContentPaneStatusPlacement.topLeading
}

private struct StatusFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect? = nil

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

private struct StatusPositionProbe: View {
    var body: some View {
        Rectangle()
            .fill(.red)
            .frame(width: 80, height: 20)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: StatusFramePreferenceKey.self,
                        value: geometry.frame(in: .named("status-container"))
                    )
                }
            }
    }
}

private struct StatusLayoutHarness: View {
    @ObservedObject var placement: StatusPlacementSelection
    @ObservedObject var frameProbe: StatusFrameProbe

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 100)
            ContentPaneStatus(placement: placement.value) {
                StatusPositionProbe()
            }
            Color.clear.frame(height: 60)
        }
        .frame(width: 400, height: 600)
        .coordinateSpace(name: "status-container")
        .onPreferenceChange(StatusFramePreferenceKey.self) { frameProbe.frame = $0 }
    }
}

private struct ContentPaneStatusLayoutFailure: Error, CustomStringConvertible {
    let description: String
}

@MainActor
@Test func loadingStatusStartsAtTopAndEmptyStatusStaysCentered() throws {
    let frameProbe = StatusFrameProbe()
    let placement = StatusPlacementSelection()
    let hostingView = NSHostingView(rootView: StatusLayoutHarness(placement: placement, frameProbe: frameProbe))
    hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
    hostingView.layoutSubtreeIfNeeded()
    guard let loadingFrame = waitForStatusFrame(in: frameProbe, nearVerticalPosition: 100) else {
        throw ContentPaneStatusLayoutFailure(description: "The loading status did not render near the top of its content region.")
    }
    #expect(loadingFrame.minY >= 95)
    #expect(loadingFrame.minY < 120)

    placement.value = .centered
    guard let emptyFrame = waitForStatusFrame(in: frameProbe, nearVerticalPosition: 320) else {
        throw ContentPaneStatusLayoutFailure(description: "The empty status did not remain centered in its content region.")
    }
    #expect(emptyFrame.midY > 300)
    #expect(emptyFrame.midY < 340)
}

@MainActor
private func waitForStatusFrame(in frameProbe: StatusFrameProbe, nearVerticalPosition expected: CGFloat) -> CGRect? {
    let deadline = Date(timeIntervalSinceNow: 1)
    while Date() < deadline {
        if let frame = frameProbe.frame,
           frame.width > 0,
           frame.height > 0,
           abs(frame.midY - expected) < 25 {
            return frame
        }
        _ = RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.025))
    }
    return nil
}
