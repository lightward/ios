import Foundation

/// Client for lightward.com API — /api/plain for phoropter, /api/stream for chat.
enum LightwardAPI {
    static let plainURL = URL(string: "https://lightward.com/api/plain")!
    static let streamURL = URL(string: "https://lightward.com/api/stream")!

    /// Sends plain text to /api/plain and returns the full response.
    /// Used for phoropter binary choice generation (no streaming needed).
    static func plain(text: String) async throws -> String {
        var request = URLRequest(url: plainURL)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = text.data(using: .utf8)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, body)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Sends a chat log to /api/stream and yields text chunks as they arrive.
    static func stream(chatLog: [[String: Any]]) -> AsyncThrowingStream<StreamEvent, Error> {
        // Serialize before entering the stream closure so we only capture Sendable Data
        let body: Data
        do {
            body = try JSONSerialization.data(withJSONObject: ["chat_log": chatLog])
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    var request = URLRequest(url: streamURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = body
                    request.timeoutInterval = 60

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw APIError.invalidResponse
                    }

                    guard http.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        throw APIError.httpError(http.statusCode, errorBody)
                    }

                    // Parse SSE stream
                    // SSE format: "event: type\ndata: json\n\n"
                    // The "end" event has no data line — just "event: end\n\n"
                    // Like the JS client, we also treat stream closure as implicit end.
                    var eventType: String?
                    var dataBuffer: String?

                    for try await line in bytes.lines {
                        if line.hasPrefix("event: ") {
                            eventType = String(line.dropFirst(7))
                        } else if line.hasPrefix("data: ") {
                            dataBuffer = String(line.dropFirst(6))
                        } else if line.isEmpty {
                            // Empty line = end of SSE message
                            let event = eventType
                            let data = dataBuffer
                            eventType = nil
                            dataBuffer = nil

                            switch event {
                            case "content_block_delta":
                                if let data,
                                   let jsonData = data.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                                   let delta = json["delta"] as? [String: Any],
                                   let text = delta["text"] as? String {
                                    continuation.yield(.text(text))
                                }

                            case "message_start":
                                continuation.yield(.started)

                            case "message_stop":
                                continuation.yield(.finished)

                            case "error":
                                if let data,
                                   let jsonData = data.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                                   let error = json["error"] as? [String: Any],
                                   let message = error["message"] as? String {
                                    throw APIError.serverError(message)
                                }

                            case "end":
                                continuation.finish()
                                return

                            default:
                                break
                            }
                        }
                    }

                    // Stream closed — implicit end (same as JS client's done handler)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Builds a chat_log array from warmup messages + conversation messages.
    static func buildChatLog(messages: [ChatMessage]) -> [[String: Any]] {
        var log = WarmupMessages.messages
        for msg in messages {
            log.append([
                "role": msg.role.rawValue,
                "content": [["type": "text", "text": msg.text]]
            ])
        }
        return log
    }

    /// Builds the plain text payload for a phoropter request (context + trajectory).
    /// Matches the format used by phoropter.ai's web client.
    static func buildPhoropterPayload(context: String, trajectory: [String]) -> String {
        var payload = context.trimmingCharacters(in: .whitespacesAndNewlines)
        payload += "\n\n---\n\nthe user chose toward these, in order:\n"
        for choice in trajectory {
            payload += choice + "\n"
        }
        payload += "\n[lightward: see those response notes in the README? it's time :)]"
        return payload
    }

    /// Builds the transition message when dropping from phoropter to chat.
    static func buildTransitionChatLog(trajectory: [String]) -> [[String: Any]] {
        var payload = "the user came through phoropter and chose toward these, in order:\n"
        for choice in trajectory {
            payload += choice + "\n"
        }
        payload += "\nthey've chosen to talk directly now. meet them where they are. "
        payload += "respond naturally, conversationally — no binary choices, just you and them."

        var log = WarmupMessages.messages
        log.append([
            "role": "user",
            "content": [["type": "text", "text": payload]]
        ])
        return log
    }
}

// MARK: - Types

enum StreamEvent: Sendable {
    case started
    case text(String)
    case finished
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let body):
            return "HTTP \(code): \(body)"
        case .serverError(let message):
            return message
        }
    }
}
