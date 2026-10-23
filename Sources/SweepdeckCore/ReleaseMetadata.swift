import Foundation

/// Reads the version metadata embedded in the app bundle for UI and diagnostics.
public enum ReleaseMetadata {
    public static func shortVersion(from infoDictionary: [String: Any]?) -> String {
        guard let value = infoDictionary?["CFBundleShortVersionString"] as? String,
              !value.isEmpty else {
            return "0.0.0"
        }
        return value
    }

    public static func buildNumber(from infoDictionary: [String: Any]?) -> String {
        guard let value = infoDictionary?["CFBundleVersion"] as? String,
              !value.isEmpty else {
            return "0"
        }
        return value
    }

    public static func footerLabel(from infoDictionary: [String: Any]?) -> String {
        let version = shortVersion(from: infoDictionary)
        let build = buildNumber(from: infoDictionary)
        if version == build {
            return "Sweepdeck \(version)"
        }
        return "Sweepdeck \(version) (build \(build))"
    }
}
