import Foundation
import SwiftUI

/// Persists sessions locally. CloudKit sync comes later.
@MainActor
@Observable
final class Store {
    private(set) var session: Session

    private static let key = "lightward_session"

    init() {
        if let data = UserDefaults.standard.data(forKey: Store.key),
           let saved = try? JSONDecoder().decode(Session.self, from: data) {
            self.session = saved
        } else {
            self.session = Session()
        }
    }

    func save() {
        session.modified = Date()
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: Store.key)
        }
    }

    func appendPhoropterChoice(_ choice: String) {
        session.phoropterTrail.append(choice)
        save()
    }

    func appendMessage(_ message: ChatMessage) {
        session.chatMessages.append(message)
        save()
    }

    func updateLastAssistantMessage(_ text: String) {
        guard let index = session.chatMessages.lastIndex(where: { $0.role == .assistant }) else {
            return
        }
        session.chatMessages[index].text = text
        save()
    }

    func reset() {
        session = Session()
        save()
    }
}
