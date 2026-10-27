import Combine
import AppKit
import Darwin
import Foundation
import Sparkle
import SweepdeckPresentation

@MainActor
final class UpdateManager: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var allowsAutomaticUpdates = false

    private let updaterDelegate: SweepdeckUpdaterDelegate
    private let controller: SPUStandardUpdaterController
    private var observations: [NSKeyValueObservation] = []
    private var modelObservations: Set<AnyCancellable> = []
    private var started = false

    init(model: AppModel) {
        let relaunchDeferral = UpdateRelaunchDeferral()
        let updaterDelegate = SweepdeckUpdaterDelegate(model: model, relaunchDeferral: relaunchDeferral)
        self.updaterDelegate = updaterDelegate
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )
        observeProtectedActivities(model, relaunchDeferral: relaunchDeferral)
        observeUpdaterSettings()
    }

    func start() {
        guard !started else { return }
        started = true
        controller.startUpdater()
        if controller.updater.automaticallyChecksForUpdates {
            controller.updater.checkForUpdatesInBackground()
        }
        scheduleSettingsRefresh()
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        controller.checkForUpdates(nil)
    }

    func setAutomaticChecksEnabled(_ enabled: Bool) {
        guard controller.updater.automaticallyChecksForUpdates != enabled else { return }
        controller.updater.automaticallyChecksForUpdates = enabled
        scheduleSettingsRefresh()
    }

    func setAutomaticDownloadsEnabled(_ enabled: Bool) {
        guard allowsAutomaticUpdates,
              controller.updater.automaticallyDownloadsUpdates != enabled else { return }
        controller.updater.automaticallyDownloadsUpdates = enabled
        scheduleSettingsRefresh()
    }

    private func observeUpdaterSettings() {
        let updater = controller.updater
        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.scheduleSettingsRefresh()
                }
            },
            updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.scheduleSettingsRefresh()
                }
            },
            updater.observe(\.automaticallyDownloadsUpdates, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.scheduleSettingsRefresh()
                }
            },
            updater.observe(\.allowsAutomaticUpdates, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.scheduleSettingsRefresh()
                }
            }
        ]
    }

    private func observeProtectedActivities(_ model: AppModel, relaunchDeferral: UpdateRelaunchDeferral) {
        Publishers.CombineLatest3(model.$busyOperation, model.$isPresentingPanel, model.$plan)
            .sink { operation, isPresentingPanel, plan in
                let activeActivities = UpdateActivityMapper.activities(
                    for: operation,
                    folderPanelPresented: isPresentingPanel,
                    cleanupPreviewPending: plan != nil
                )
                Task { @MainActor in
                    relaunchDeferral.synchronize(activeActivities: activeActivities)
                }
            }
            .store(in: &modelObservations)
    }

    private func refreshSettings() {
        let updater = controller.updater
        if canCheckForUpdates != updater.canCheckForUpdates {
            canCheckForUpdates = updater.canCheckForUpdates
        }
        if automaticallyChecksForUpdates != updater.automaticallyChecksForUpdates {
            automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        }
        if automaticallyDownloadsUpdates != updater.automaticallyDownloadsUpdates {
            automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        }
        if allowsAutomaticUpdates != updater.allowsAutomaticUpdates {
            allowsAutomaticUpdates = updater.allowsAutomaticUpdates
        }
    }

    private func scheduleSettingsRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshSettings()
        }
    }
}

@MainActor
private final class SweepdeckUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    private weak var model: AppModel?
    private let relaunchDeferral: UpdateRelaunchDeferral

    init(model: AppModel, relaunchDeferral: UpdateRelaunchDeferral) {
        self.model = model
        self.relaunchDeferral = relaunchDeferral
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard let model, !model.isTerminating, !model.isPresentingPanel else {
            throw NSError(
                domain: "local.sweepdeck.updates",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Updates are unavailable while Sweepdeck is closing or a folder panel is open."]
            )
        }
        model.setUpdateSessionInProgress(true)
    }

    func updater(
        _ updater: SPUUpdater,
        shouldPostponeRelaunchForUpdate item: SUAppcastItem,
        untilInvokingBlock installHandler: @escaping () -> Void
    ) -> Bool {
        synchronizeProtectedActivities()
        return relaunchDeferral.postponeRelaunchIfNeeded(installHandler)
    }

    private func synchronizeProtectedActivities() {
        guard let model else { return }
        relaunchDeferral.synchronize(
            activeActivities: UpdateActivityMapper.activities(
                for: model.busyOperation,
                folderPanelPresented: model.isPresentingPanel,
                cleanupPreviewPending: model.plan != nil
            )
        )
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        if Bundle.main.object(forInfoDictionaryKey: "SweepdeckTestQuarantineBeforeInstall") as? Bool == true {
            applyTestQuarantineBeforeInstall()
        }
        guard Bundle.main.object(forInfoDictionaryKey: "SweepdeckTestQuitAfterAutomaticDownload") as? Bool == true else {
            return
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let model = self?.model,
                  model.busyOperation == nil,
                  !model.isPresentingPanel else {
                return
            }
            NSApp.terminate(nil)
        }
    }

    private func applyTestQuarantineBeforeInstall() {
        let timestamp = String(Int(Date().timeIntervalSince1970), radix: 16)
        let quarantineValue = "0081;\(timestamp);SweepdeckUpdateTest;\(UUID().uuidString)"
        let result = Bundle.main.bundleURL.path.withCString { path in
            "com.apple.quarantine".withCString { name in
                quarantineValue.withCString { value in
                    setxattr(path, name, value, quarantineValue.utf8.count, 0, 0)
                }
            }
        }
        guard result == 0,
              let markerPath = Bundle.main.object(forInfoDictionaryKey: "SweepdeckTestQuarantineMarker") as? String else {
            NSLog("Could not quarantine the isolated updater test app before installation: %d", errno)
            return
        }
        do {
            try Data("quarantine-attached\n".utf8).write(to: URL(fileURLWithPath: markerPath), options: .atomic)
        } catch {
            NSLog("Could not write the isolated updater quarantine marker: %@", error.localizedDescription)
        }
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        model?.setUpdateSessionInProgress(false)
    }
}
