public enum BusyOperation: Equatable, Sendable {
    case scanning
    case validating
    case cleanup

    public var title: String {
        switch self {
        case .scanning: "Scanning authorized folders"
        case .validating: "Validating selection"
        case .cleanup: "Moving confirmed files to Trash"
        }
    }
}

public enum UpdateActivityMapper {
    public static func activities(
        for operation: BusyOperation?,
        folderPanelPresented: Bool,
        cleanupPreviewPending: Bool = false
    ) -> Set<UpdateActivity> {
        var activities = Set<UpdateActivity>()
        switch operation {
        case .scanning:
            activities.insert(.scanning)
        case .validating:
            activities.insert(.preparingPreview)
        case .cleanup:
            activities.insert(.movingToTrash)
        case nil:
            break
        }
        if folderPanelPresented {
            activities.insert(.presentingFolderPanel)
        }
        if cleanupPreviewPending {
            activities.insert(.preparingPreview)
        }
        return activities
    }
}
