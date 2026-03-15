import Foundation
import SwiftUI

/// Drives the phoropter binary choice flow.
@MainActor
@Observable
final class PhoropterViewModel {
    // Entry pairs — same as phoropter.ai
    static let entryPairs: [(String, String)] = [
        ("Something is pressing", "Something is unclear"),
        ("I know what it is", "I don't know what it is"),
        ("I want to move", "I want to rest"),
        ("I feel something", "I feel nothing"),
    ]

    var entryIndex = 0
    var entrySelection: String?
    var history: [String] = []
    var currentOptions: (String, String)?
    var loading = false
    var converged = false
    var error: String?
    var aiResponseCount = 0

    private let store: Store
    private let phoropterContext: String
    private var currentTask: Task<Void, Never>?

    var trail: [String] {
        guard let entry = entrySelection else { return [] }
        return [entry] + history
    }

    var entryPair: (String, String) {
        Self.entryPairs[entryIndex]
    }

    init(store: Store) {
        self.store = store
        self.phoropterContext = Self.loadContext()
    }

    private static func loadContext() -> String {
        guard let url = Bundle.main.url(forResource: "PhoropterContext", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
    }

    func cycleEntry() {
        entryIndex = (entryIndex + 1) % Self.entryPairs.count
    }

    func selectEntry(_ choice: String) {
        entrySelection = choice
        history = []
        currentOptions = nil
        aiResponseCount = 0
        converged = false
        store.appendPhoropterChoice(choice)
        fetchNextPair()
    }

    func select(_ choice: String) {
        history.append(choice)
        currentOptions = nil
        store.appendPhoropterChoice(choice)
        fetchNextPair()
    }

    func cycle() {
        currentOptions = nil
        fetchNextPair()
    }

    func retry() {
        error = nil
        fetchNextPair()
    }

    func startOver() {
        entryIndex = 0
        entrySelection = nil
        history = []
        currentOptions = nil
        loading = false
        converged = false
        error = nil
        aiResponseCount = 0
        store.reset()
    }

    private func fetchNextPair() {
        currentTask?.cancel()
        loading = true
        error = nil

        currentTask = Task {
            do {
                let payload = LightwardAPI.buildPhoropterPayload(
                    context: phoropterContext,
                    trajectory: trail
                )

                let response = try await LightwardAPI.plain(text: payload)
                let parsed = parseResponse(response)
                loading = false

                guard let options = parsed else {
                    error = "Couldn't parse response"
                    return
                }

                // Check for convergence
                let trailLower = trail.map { $0.lowercased() }
                if trailLower.contains(options.0.lowercased()) ||
                   trailLower.contains(options.1.lowercased()) {
                    converged = true
                }

                aiResponseCount += 1
                currentOptions = options
            } catch {
                loading = false
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func parseResponse(_ text: String) -> (String, String)? {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return nil }
        return (lines[0], lines[1])
    }
}
