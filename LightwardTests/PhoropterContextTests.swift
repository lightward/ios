import Testing
@testable import Lightward

struct PhoropterContextTests {
    private let readme = "# phoropter.ai\n\n## Response notes\n\nfresh"
    private let older = "# phoropter.ai\n\n## Response notes\n\nolder"
    private let bundled = "# phoropter.ai\n\n## Response notes\n\nbundled"

    @Test func freshFetchWins() {
        #expect(PhoropterContext.resolve(fetched: readme, cached: older, bundled: bundled) == readme)
    }

    @Test func cacheWhenFetchFails() {
        #expect(PhoropterContext.resolve(fetched: nil, cached: older, bundled: bundled) == older)
    }

    @Test func bundleWhenNothingElse() {
        #expect(PhoropterContext.resolve(fetched: nil, cached: nil, bundled: bundled) == bundled)
    }

    @Test func unusableFetchIsPassedOver() {
        let errorPage = "<html><body>404</body></html>"
        #expect(PhoropterContext.resolve(fetched: errorPage, cached: older, bundled: bundled) == older)
        #expect(PhoropterContext.resolve(fetched: "", cached: nil, bundled: bundled) == bundled)
    }

    @Test func bundledCopyIsUsable() {
        #expect(PhoropterContext.isUsable(PhoropterContext.bundled()))
    }
}
