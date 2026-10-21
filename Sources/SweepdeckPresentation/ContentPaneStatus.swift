import SwiftUI

public enum ContentPaneStatusPlacement {
    case centered
    case topLeading
}

public struct ContentPaneStatus<Content: View>: View {
    private let alignment: Alignment
    private let content: Content

    public init(
        placement: ContentPaneStatusPlacement,
        @ViewBuilder content: () -> Content
    ) {
        switch placement {
        case .centered:
            alignment = .center
        case .topLeading:
            alignment = .topLeading
        }
        self.content = content()
    }

    public var body: some View {
        content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}
