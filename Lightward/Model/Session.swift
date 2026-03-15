import Foundation

/// A single message in a chat conversation.
struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let role: Role
    var text: String
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(role: Role, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.timestamp = Date()
    }
}

/// The complete state of a session — phoropter trajectory + chat.
struct Session: Codable, Identifiable {
    let id: UUID
    var phoropterTrail: [String]
    var chatMessages: [ChatMessage]
    let created: Date
    var modified: Date

    init() {
        self.id = UUID()
        self.phoropterTrail = []
        self.chatMessages = []
        self.created = Date()
        self.modified = Date()
    }
}
