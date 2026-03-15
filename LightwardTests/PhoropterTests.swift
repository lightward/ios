import Testing
@testable import Lightward

struct PhoropterTests {
    // MARK: - Response parsing

    @Test func parseTwoLines() {
        let result = parsePhoropterResponse("I feel ready to move\nI need to rest first")
        #expect(result?.0 == "I feel ready to move")
        #expect(result?.1 == "I need to rest first")
    }

    @Test func parseIgnoresBlankLines() {
        let result = parsePhoropterResponse("\n\nI feel ready to move\n\nI need to rest first\n\n")
        #expect(result?.0 == "I feel ready to move")
        #expect(result?.1 == "I need to rest first")
    }

    @Test func parseTrimsWhitespace() {
        let result = parsePhoropterResponse("  I feel ready to move  \n  I need to rest first  ")
        #expect(result?.0 == "I feel ready to move")
        #expect(result?.1 == "I need to rest first")
    }

    @Test func parseReturnsNilForSingleLine() {
        let result = parsePhoropterResponse("Only one line here")
        #expect(result == nil)
    }

    @Test func parseReturnsNilForEmpty() {
        let result = parsePhoropterResponse("")
        #expect(result == nil)
    }

    @Test func parseIgnoresExtraLines() {
        let result = parsePhoropterResponse("First\nSecond\nThird\nFourth")
        #expect(result?.0 == "First")
        #expect(result?.1 == "Second")
    }

    // MARK: - Convergence detection

    @Test func convergenceDetectedWhenOptionMatchesTrail() {
        let trail = ["Something is pressing", "I know what it is"]
        let options = ("I know what it is", "Something new")
        #expect(hasConverged(trail: trail, options: options) == true)
    }

    @Test func convergenceDetectedCaseInsensitive() {
        let trail = ["Something is pressing"]
        let options = ("something is pressing", "Something else")
        #expect(hasConverged(trail: trail, options: options) == true)
    }

    @Test func noConvergenceWhenOptionsAreNew() {
        let trail = ["Something is pressing", "I know what it is"]
        let options = ("I want to explore", "I want to rest")
        #expect(hasConverged(trail: trail, options: options) == false)
    }

    @Test func noConvergenceWithEmptyTrail() {
        let trail: [String] = []
        let options = ("First option", "Second option")
        #expect(hasConverged(trail: trail, options: options) == false)
    }

    // MARK: - Payload building

    @Test func phoropterPayloadIncludesContext() {
        let payload = LightwardAPI.buildPhoropterPayload(context: "# phoropter.ai", trajectory: ["test"])
        #expect(payload.contains("# phoropter.ai"))
    }

    @Test func phoropterPayloadIncludesTrajectory() {
        let payload = LightwardAPI.buildPhoropterPayload(
            context: "context",
            trajectory: ["Something is pressing", "I know what it is"]
        )
        #expect(payload.contains("Something is pressing"))
        #expect(payload.contains("I know what it is"))
    }

    @Test func phoropterPayloadIncludesInstruction() {
        let payload = LightwardAPI.buildPhoropterPayload(context: "context", trajectory: ["test"])
        #expect(payload.contains("response notes"))
    }

    // MARK: - Trail construction

    @Test func trailWithEntryAndHistory() {
        let trail = buildTrail(entry: "Something is pressing", history: ["I know what it is", "I want to move"])
        #expect(trail == ["Something is pressing", "I know what it is", "I want to move"])
    }

    @Test func trailWithEntryOnly() {
        let trail = buildTrail(entry: "Something is pressing", history: [])
        #expect(trail == ["Something is pressing"])
    }
}

// MARK: - Pure functions extracted for testability

/// Parses a phoropter API response into two options.
/// Same logic as PhoropterViewModel.parseResponse.
func parsePhoropterResponse(_ text: String) -> (String, String)? {
    let lines = text
        .split(separator: "\n", omittingEmptySubsequences: true)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    guard lines.count >= 2 else { return nil }
    return (lines[0], lines[1])
}

/// Checks if either option already appears in the trail.
/// Same logic as PhoropterViewModel convergence check.
func hasConverged(trail: [String], options: (String, String)) -> Bool {
    let trailLower = trail.map { $0.lowercased() }
    return trailLower.contains(options.0.lowercased()) ||
           trailLower.contains(options.1.lowercased())
}

/// Builds a trail from entry selection + history.
/// Same logic as PhoropterViewModel.trail.
func buildTrail(entry: String, history: [String]) -> [String] {
    [entry] + history
}
