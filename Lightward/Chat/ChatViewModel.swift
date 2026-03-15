import Foundation
import SwiftUI

/// Drives the streaming chat with Lightward AI.
@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var streaming = false
    var displayedText = ""
    var error: String?

    private let store: Store
    private let phoropterTrail: [String]
    private var hasInitiated = false
    private var currentTask: Task<Void, Never>?

    // Streaming display — queue chunks, release at human reading pace
    private var chunkQueue: [String] = []
    private var fullText = ""
    private var displayTask: Task<Void, Never>?

    init(store: Store, phoropterTrail: [String]) {
        self.store = store
        self.phoropterTrail = phoropterTrail

        // Restore existing chat messages, filtering out empty ones from failed attempts
        self.messages = store.session.chatMessages.filter { !$0.text.isEmpty }
        Log.chat.info("Init: \(self.messages.count) restored messages, trail: \(phoropterTrail.count) items")
    }

    /// Initiates the conversation with the phoropter trajectory as context.
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
        displayTask?.cancel()
        streaming = true
        fullText = ""
        displayedText = ""
        chunkQueue = []
        error = nil

        currentTask = Task {
            do {
                Log.chat.info("Stream: sending request (\(chatLog.count) messages in chat_log)")
                var chunkCount = 0

                for try await event in LightwardAPI.stream(chatLog: chatLog) {
                    switch event {
                    case .text(let chunk):
                        chunkCount += 1
                        fullText += chunk
                        enqueueChunk(chunk)

                    case .started:
                        Log.chat.debug("Stream: started")

                    case .finished:
                        Log.chat.debug("Stream: finished after \(chunkCount) chunks")
                    }
                }

                Log.chat.info("Stream: complete, \(chunkCount) chunks, length: \(self.fullText.count)")

                if chunkCount == 0 {
                    Log.chat.error("Stream: zero chunks received")
                    streaming = false
                    self.error = "No response received"
                    ErrorReporter.report(category: "chat", message: "Stream completed with zero text chunks")
                }
                // streaming = false is set when the display queue drains
            } catch {
                Log.chat.error("Stream error: \(error, privacy: .public)")
                flushDisplay()
                streaming = false
                if !Task.isCancelled {
                    if messages.last?.text.isEmpty == true {
                        messages.removeLast()
                    }
                    self.error = error.localizedDescription
                    ErrorReporter.report(category: "chat", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Throttled display (matches JS client's MessageStreamController)

    private func enqueueChunk(_ chunk: String) {
        chunkQueue.append(chunk)
        if displayTask == nil {
            startDisplayLoop()
        }
    }

    private func startDisplayLoop() {
        displayTask = Task {
            while !Task.isCancelled {
                guard !chunkQueue.isEmpty else {
                    // Queue empty — check if stream is done
                    if currentTask == nil || fullText == displayedText {
                        finishDisplay()
                        return
                    }
                    // Wait a tick for more chunks
                    try? await Task.sleep(for: .milliseconds(50))
                    continue
                }

                let chunk = chunkQueue.removeFirst()
                displayedText += chunk

                // Update or create the assistant message
                if let last = messages.indices.last, messages[last].role == .assistant {
                    messages[last].text = displayedText
                } else {
                    messages.append(ChatMessage(role: .assistant, text: displayedText))
                }

                // Random delay between 30-80ms per chunk for natural reading pace
                // (shorter than the JS client's 200-400ms because iOS chunks are smaller)
                let delay = Int.random(in: 30...80)
                try? await Task.sleep(for: .milliseconds(delay))
            }
        }
    }

    private func flushDisplay() {
        displayTask?.cancel()
        displayTask = nil
        displayedText = fullText
        if !displayedText.isEmpty {
            if let last = messages.indices.last, messages[last].role == .assistant {
                messages[last].text = displayedText
            } else {
                messages.append(ChatMessage(role: .assistant, text: displayedText))
            }
        }
    }

    private func finishDisplay() {
        displayTask = nil
        streaming = false
        // Save completed message
        if let last = messages.last, !last.text.isEmpty {
            store.appendMessage(last)
        }
    }
}
