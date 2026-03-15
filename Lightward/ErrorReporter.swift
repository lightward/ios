import Foundation
import UIKit

/// Reports errors to GitHub Issues on lightward/ios.
/// No conversation content — just error metadata.
enum ErrorReporter {
    // Fine-grained PAT: lightward/ios issues:write only
    private static let token = Secrets.githubIssuesToken
    private static let repo = "lightward/ios"

    /// Reports an error as a GitHub issue.
    static func report(
        category: String,
        message: String,
        file: String = #file,
        line: Int = #line
    ) {
        Task.detached {
            let title = "[\(category)] \(message.prefix(80))"

            let body = """
            **Category:** \(category)
            **Error:** \(message)
            **Location:** \(URL(fileURLWithPath: file).lastPathComponent):\(line)

            **Device:** \(await deviceInfo())
            **App version:** \(appVersion())

            ---
            *Reported automatically by the app. No user data included.*
            """

            await createIssue(title: title, body: body)
        }
    }

    private static func createIssue(title: String, body: String) async {
        guard !token.isEmpty else {
            Log.api.warning("ErrorReporter: No GitHub token configured")
            return
        }

        let url = URL(string: "https://api.github.com/repos/\(repo)/issues")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "title": title,
            "body": body,
            "labels": ["auto-reported"]
        ])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 201 {
                Log.api.info("ErrorReporter: Issue created")
            } else {
                Log.api.error("ErrorReporter: Unexpected status")
            }
        } catch {
            Log.api.error("ErrorReporter: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    @MainActor
    private static func deviceInfo() -> String {
        let device = UIDevice.current
        return "\(device.model), iOS \(device.systemVersion)"
    }
}
