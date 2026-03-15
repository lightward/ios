import Foundation

/// App secrets injected at build time via Info.plist / build settings.
/// Never hardcoded in source.
enum Secrets {
    static let githubIssuesToken: String = {
        Bundle.main.infoDictionary?["ERROR_REPORTER_TOKEN"] as? String ?? ""
    }()
}
