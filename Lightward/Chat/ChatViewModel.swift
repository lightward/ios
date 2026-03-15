import Foundation
import SwiftUI

/// Drives the streaming chat with Lightward AI.
@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var streaming = false
    var streamingText = ""

    private let store: Store
    private let phoropterTrail: [String]
    private var hasInitiated = false
    private var currentTask: Task<Void, Never>?

    init(store: Store, phoropterTrail: [String]) {
        self.store = store
        self.phoropterTrail = phoropterTrail

        // Restore any existing chat messages
        self.messages = store.session.chatMessages
    }

    /// Initiates the conversation with the phoropter trajectory as context.
    func initiateIfNeeded() {
        guard !hasInitiated, messages.isEmpty else {
            hasInitiated = true
            return
        }
        hasInitiated = true
        streamResponse(chatLog: LightwardAPI.buildTransitionChatLog(trajectory: phoropterTrail))
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !streaming else { return }

        inputText = ""

        let userMessage = ChatMessage(role: .user, text: text)
        messages.append(userMessage)
        store.appendMessage(userMessage)

        let chatLog = LightwardAPI.buildChatLog(messages: messages)
        streamResponse(chatLog: chatLog)
    }

    private func streamResponse(chatLog: [[String: Any]]) {
        currentTask?.cancel()
        streaming = true
        streamingText = ""

        // Add placeholder assistant message
        let placeholder = ChatMessage(role: .assistant, text: "")
        messages.append(placeholder)

        currentTask = Task { @MainActor in
            do {
                for try await event in LightwardAPI.stream(chatLog: chatLog) {
                    switch event {
                    case .text(let chunk):
                        streamingText += chunk
                        // Update the last message in place
                        if let last = messages.indices.last {
                            messages[last].text = streamingText
                        }

                    case .started:
                        break

                    case .finished:
                        break
                    }
                }

                streaming = false
                // Save the completed message
                if let last = messages.last {
                    store.appendMessage(last)
                }
            } catch {
                streaming = false
                if !Task.isCancelled {
                    // Remove placeholder on error
                    if messages.last?.text.isEmpty == true {
                        messages.removeLast()
                    }
                }
            }
        }
    }
}
