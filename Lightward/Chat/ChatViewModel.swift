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
    var error: String?

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
    /// Called from ChatView.onAppear so it fires when the view is actually visible.
    func initiateIfNeeded() {
        guard !hasInitiated else { return }
        hasInitiated = true
        guard messages.isEmpty else { return }

        Log.chat.info("Initiating with trail: \(self.phoropterTrail, privacy: .public)")
        streamResponse(chatLog: LightwardAPI.buildTransitionChatLog(trajectory: phoropterTrail))
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !streaming else { return }

        inputText = ""
        error = nil

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
        error = nil

        // Add placeholder assistant message
        let placeholder = ChatMessage(role: .assistant, text: "")
        messages.append(placeholder)

        currentTask = Task {
            do {
                Log.chat.info("Starting stream request")
                for try await event in LightwardAPI.stream(chatLog: chatLog) {
                    switch event {
                    case .text(let chunk):
                        streamingText += chunk
                        if let last = messages.indices.last {
                            messages[last].text = streamingText
                        }

                    case .started:
                        Log.chat.debug("Stream started")

                    case .finished:
                        Log.chat.debug("Stream finished")
                    }
                }

                streaming = false
                if let last = messages.last, !last.text.isEmpty {
                    store.appendMessage(last)
                }
                Log.chat.info("Stream complete, length: \(self.messages.last?.text.count ?? 0)")
            } catch {
                Log.chat.error("Stream error: \(error, privacy: .public)")
                streaming = false
                if !Task.isCancelled {
                    if messages.last?.text.isEmpty == true {
                        messages.removeLast()
                    }
                    self.error = error.localizedDescription
                }
            }
        }
    }
}
