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

        // Restore existing chat messages, filtering out empty ones from failed attempts
        self.messages = store.session.chatMessages.filter { !$0.text.isEmpty }
        Log.chat.info("Init: \(self.messages.count) restored messages, trail: \(phoropterTrail.count) items")
    }

    /// Initiates the conversation with the phoropter trajectory as context.
    /// Called from ChatView.onAppear so it fires when the view is actually visible.
    func initiateIfNeeded() {
        guard !hasInitiated else { return }
        hasInitiated = true
        guard messages.isEmpty else {
            Log.chat.info("Skipping initiation: \(self.messages.count) messages already present")
            return
        }

        Log.chat.info("Initiating with trail: \(self.phoropterTrail, privacy: .public)")
        streamResponse(chatLog: LightwardAPI.buildTransitionChatLog(trajectory: phoropterTrail))
    }

    func retry() {
        error = nil
        hasInitiated = false
        initiateIfNeeded()
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

        currentTask = Task {
            do {
                Log.chat.info("Stream: sending request (\(chatLog.count) messages in chat_log)")
                var chunkCount = 0

                for try await event in LightwardAPI.stream(chatLog: chatLog) {
                    switch event {
                    case .text(let chunk):
                        chunkCount += 1
                        streamingText += chunk
                        // Update or create the assistant message
                        if let last = messages.indices.last, messages[last].role == .assistant {
                            messages[last].text = streamingText
                        } else {
                            messages.append(ChatMessage(role: .assistant, text: streamingText))
                        }

                    case .started:
                        Log.chat.debug("Stream: started")

                    case .finished:
                        Log.chat.debug("Stream: finished after \(chunkCount) chunks")
                    }
                }

                streaming = false
                Log.chat.info("Stream: complete, \(chunkCount) chunks, final length: \(self.streamingText.count)")

                if chunkCount == 0 {
                    Log.chat.error("Stream: completed with zero chunks — no content received")
                    self.error = "No response received"
                    ErrorReporter.report(category: "chat", message: "Stream completed with zero text chunks")
                } else if let last = messages.last, !last.text.isEmpty {
                    store.appendMessage(last)
                }
            } catch {
                Log.chat.error("Stream error: \(error, privacy: .public)")
                streaming = false
                if !Task.isCancelled {
                    // Remove empty assistant message on error
                    if let last = messages.indices.last, messages[last].text.isEmpty {
                        messages.removeLast()
                    }
                    self.error = error.localizedDescription
                    ErrorReporter.report(category: "chat", message: error.localizedDescription)
                }
            }
        }
    }
}
