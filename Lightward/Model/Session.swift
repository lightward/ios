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

    init(
        id: UUID = UUID(),
        phoropterTrail: [String] = [],
        chatMessages: [ChatMessage] = [],
        created: Date = Date(),
        modified: Date = Date()
    ) {
        self.id = id
        self.phoropterTrail = phoropterTrail
        self.chatMessages = chatMessages
        self.created = created
        self.modified = modified
    }
}
