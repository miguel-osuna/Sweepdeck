import SweepdeckPresentation
import Testing

@Test func busyOperationsMapToProtectedUpdateActivities() {
    #expect(UpdateActivityMapper.activities(for: .scanning, folderPanelPresented: false) == [.scanning])
    #expect(UpdateActivityMapper.activities(for: .validating, folderPanelPresented: false) == [.preparingPreview])
    #expect(UpdateActivityMapper.activities(for: .cleanup, folderPanelPresented: false) == [.movingToTrash])
}

@Test func folderPanelAddsProtectionAlongsideTheCurrentOperation() {
    #expect(UpdateActivityMapper.activities(for: nil, folderPanelPresented: true) == [.presentingFolderPanel])
    #expect(UpdateActivityMapper.activities(for: .validating, folderPanelPresented: true) == [
        .preparingPreview,
        .presentingFolderPanel
    ])
    #expect(UpdateActivityMapper.activities(for: nil, folderPanelPresented: false).isEmpty)
}

@Test func pendingCleanupPreviewDefersRelaunchAfterValidationFinishes() {
    #expect(UpdateActivityMapper.activities(
        for: nil,
        folderPanelPresented: false,
        cleanupPreviewPending: true
    ) == [.preparingPreview])
}

@MainActor
@Test func postponedInstallRunsAfterEveryProtectedActivityFinishes() {
    let deferral = UpdateRelaunchDeferral()
    var installCount = 0
    deferral.synchronize(activeActivities: [.scanning, .movingToTrash])

    let postponed = deferral.postponeRelaunchIfNeeded {
        installCount += 1
    }

    #expect(postponed)
    #expect(installCount == 0)
    deferral.synchronize(activeActivities: [.movingToTrash])
    #expect(installCount == 0)
    deferral.synchronize(activeActivities: [])
    #expect(installCount == 1)
}

@MainActor
@Test func idleUpdateRelaunchProceedsWithoutPostponement() {
    let deferral = UpdateRelaunchDeferral()
    var installCount = 0

    let postponed = deferral.postponeRelaunchIfNeeded {
        installCount += 1
    }

    #expect(!postponed)
    #expect(installCount == 0)
}

@MainActor
@Test func everyProtectedActivityDefersRelaunchUntilItFinishes() {
    let activities: [UpdateActivity] = [
        .scanning,
        .preparingPreview,
        .movingToTrash,
        .presentingFolderPanel
    ]

    for activity in activities {
        let deferral = UpdateRelaunchDeferral()
        var installCount = 0
        deferral.synchronize(activeActivities: [activity])

        let postponed = deferral.postponeRelaunchIfNeeded {
            installCount += 1
        }

        #expect(postponed)
        #expect(installCount == 0)
        deferral.synchronize(activeActivities: [])
        #expect(installCount == 1)
    }
}

@MainActor
@Test func synchronizingActivitiesDoesNotResumeBetweenProtectedStates() {
    let deferral = UpdateRelaunchDeferral()
    var installCount = 0
    deferral.synchronize(activeActivities: [.scanning])

    let postponed = deferral.postponeRelaunchIfNeeded {
        installCount += 1
    }

    #expect(postponed)
    deferral.synchronize(activeActivities: [.preparingPreview])
    #expect(installCount == 0)
    deferral.synchronize(activeActivities: [])
    #expect(installCount == 1)
}
