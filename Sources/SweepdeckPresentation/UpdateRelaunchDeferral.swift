public enum UpdateActivity: Hashable, Sendable {
    case scanning
    case preparingPreview
    case movingToTrash
    case presentingFolderPanel
}

@MainActor
public final class UpdateRelaunchDeferral {
    private var activeActivities = Set<UpdateActivity>()
    private var pendingInstallHandlers: [() -> Void] = []

    public init() {}

    public func synchronize(activeActivities newActivities: Set<UpdateActivity>) {
        activeActivities = newActivities
        resumePendingInstallsIfIdle()
    }

    @discardableResult
    public func postponeRelaunchIfNeeded(_ installHandler: @escaping () -> Void) -> Bool {
        guard !activeActivities.isEmpty else { return false }
        pendingInstallHandlers.append(installHandler)
        return true
    }

    private func resumePendingInstallsIfIdle() {
        guard activeActivities.isEmpty, !pendingInstallHandlers.isEmpty else { return }
        let handlers = pendingInstallHandlers
        pendingInstallHandlers.removeAll()
        handlers.forEach { $0() }
    }
}
