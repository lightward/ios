import Testing
@testable import Lightward

struct ChatLogTests {
    private func text(_ entry: [String: Any]) -> String? {
        ((entry["content"] as? [[String: Any]])?.first)?["text"] as? String
    }

    private func markerCount(_ log: [[String: Any]]) -> Int {
        log.reduce(0) { count, entry in
            count + ((entry["content"] as? [[String: Any]]) ?? []).filter { $0["cache_control"] != nil }.count
        }
    }

    // MARK: - The handoff is the frame

    @Test func openingTurnIsTheHandoffAlone() {
        let log = LightwardAPI.buildChatLog(trajectory: ["Something is pressing.", "I want to rest."])
        #expect(log.count == 1)
        #expect(log[0]["role"] as? String == "user")
        #expect(text(log[0])?.contains("Something is pressing.\nI want to rest.\n") == true)
        #expect(markerCount(log) == 1)
    }

    @Test func laterTurnsKeepTheTrailInContext() {
        let messages = [
            ChatMessage(role: .assistant, text: "hi"),
            ChatMessage(role: .user, text: "hello"),
        ]
        let log = LightwardAPI.buildChatLog(trajectory: ["I feel something."], messages: messages)
        #expect(log.count == 3)
        #expect(log[0]["role"] as? String == "user")
        #expect(text(log[0])?.contains("I feel something.") == true)
        #expect(log[1]["role"] as? String == "assistant")
        #expect(text(log[2]) == "hello")
    }

    @Test func exactlyOneMarkerOnTheHandoff() {
        let messages = [
            ChatMessage(role: .assistant, text: "hi"),
            ChatMessage(role: .user, text: "hello"),
        ]
        let log = LightwardAPI.buildChatLog(trajectory: ["I feel something."], messages: messages)
        #expect(markerCount(log) == 1)
        let first = (log[0]["content"] as? [[String: Any]])?.first
        #expect(first?["cache_control"] as? [String: String] == ["type": "ephemeral"])
    }

    @Test func frameIsStableAcrossTurns() {
        let trail = ["I know what it is.", "I want to move."]
        let first = LightwardAPI.buildChatLog(trajectory: trail)
        let later = LightwardAPI.buildChatLog(
            trajectory: trail,
            messages: [ChatMessage(role: .assistant, text: "hi"), ChatMessage(role: .user, text: "yes")]
        )
        #expect(text(first[0]) == text(later[0]))
    }
}
