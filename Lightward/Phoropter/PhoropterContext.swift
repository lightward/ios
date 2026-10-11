import Foundation

/// The phoropter's context — the README that phoropter.ai itself loads at runtime.
///
/// One source for both clients: fetched from where phoropter.ai publishes it, so a README
/// edit reaches iOS when the site deploys, with nothing to copy across repos. The last good
/// fetch is cached; the bundled PhoropterContext.txt is only the cold-start fallback.
enum PhoropterContext {
    static let remoteURL = URL(string: "https://phoropter.ai/README.md")!
    static let cacheKey = "phoropterContext.cached"

    /// The section the payload's closing instruction points the model back to.
    static let requiredSection = "## Response notes"

    /// Fetches the published README, falling back to the last good fetch, then the bundle.
    static func load() async -> String {
        let fetched = await fetchRemote()
        let cached = UserDefaults.standard.string(forKey: cacheKey)
        if let fetched, isUsable(fetched) {
            UserDefaults.standard.set(fetched, forKey: cacheKey)
        }
        let context = resolve(fetched: fetched, cached: cached, bundled: bundled())
        Log.phoropter.info("Context: \(source(fetched: fetched, cached: cached), privacy: .public), \(context.count) chars")
        return context
    }

    /// Fresh beats cached beats bundled; anything that doesn't look like the README is passed over.
    static func resolve(fetched: String?, cached: String?, bundled: String) -> String {
        if let fetched, isUsable(fetched) { return fetched }
        if let cached, isUsable(cached) { return cached }
        return bundled
    }

    /// A fetch can succeed and still not be the README (an error page, a truncated body).
    static func isUsable(_ text: String) -> Bool {
        text.contains(requiredSection)
    }

    static func bundled() -> String {
        guard let url = Bundle.main.url(forResource: "PhoropterContext", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
    }

    private static func fetchRemote() async -> String? {
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            Log.phoropter.error("Context fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func source(fetched: String?, cached: String?) -> String {
        if let fetched, isUsable(fetched) { return "phoropter.ai" }
        if let cached, isUsable(cached) { return "cache" }
        return "bundle"
    }
}
