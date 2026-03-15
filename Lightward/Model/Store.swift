import Foundation
import SwiftUI

/// Persists sessions locally and syncs via CloudKit.
@MainActor
@Observable
final class Store {
    private(set) var session: Session

    private let sync: SyncCoordinator
    private var systemFields: Data?

    static let containerIdentifier = "iCloud.com.lightward"

    init() {
        let (loaded, fields) = Self.loadFromDisk()
        self.session = loaded ?? Session()
        self.systemFields = fields
        self.sync = SyncCoordinator(containerIdentifier: Self.containerIdentifier)

        Task {
            await setupSync()
        }
    }

    private func setupSync() async {
        await sync.setCallbacks(
            onFetched: { [weak self] session, fields in
                Task { @MainActor in
                    self?.handleRemoteSession(session, systemFields: fields)
                }
            },
            onDeleted: { [weak self] _ in
                Task { @MainActor in
                    self?.session = Session()
                    self?.saveToDisk()
                }
            }
        )
        await sync.start()
    }

    private func handleRemoteSession(_ remote: Session, systemFields: Data) {
        // Most recently modified wins for single-user cross-device sync
        if remote.modified > session.modified {
            self.session = remote
            self.systemFields = systemFields
            saveToDisk()
        }
    }

    func save() {
        session.modified = Date()
        saveToDisk()
        syncToCloud()
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
        // Don't sync every streaming chunk — just save locally
        saveToDisk()
    }

    func reset() {
        session = Session()
        systemFields = nil
        save()
    }

    // MARK: - CloudKit

    private func syncToCloud() {
        let record = SessionRecordConverter.record(from: session, existingSystemFields: systemFields)
        Task {
            await sync.save(record)
        }
    }

    // MARK: - Local persistence

    private static let fileName = "session.json"

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    private static var systemFieldsURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("session_ck_fields.dat")
    }

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(session) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
        if let fields = systemFields {
            try? fields.write(to: Self.systemFieldsURL, options: .atomic)
        }
    }

    private static func loadFromDisk() -> (Session?, Data?) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let session: Session? = {
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return try? decoder.decode(Session.self, from: data)
        }()

        let fields = try? Data(contentsOf: systemFieldsURL)

        return (session, fields)
    }
}
