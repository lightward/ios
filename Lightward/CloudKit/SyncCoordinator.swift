import CloudKit
import Foundation

/// Syncs sessions to CloudKit private database via CKSyncEngine.
/// Single user, single zone — much simpler than Softer's dual-engine setup.
actor SyncCoordinator {
    private let container: CKContainer
    private let database: CKDatabase
    private var engine: CKSyncEngine?

    /// Cache of records pending save, keyed by recordName.
    private var pendingRecords: [String: CKRecord] = [:]

    private var onSessionFetched: (@Sendable (Session, Data) -> Void)?
    private var onSessionDeleted: (@Sendable (String) -> Void)?

    private let stateKey = "SyncCoordinatorState-LightwardZone"

    init(containerIdentifier: String) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.privateCloudDatabase
    }

    func setCallbacks(
        onFetched: @escaping @Sendable (Session, Data) -> Void,
        onDeleted: @escaping @Sendable (String) -> Void
    ) {
        self.onSessionFetched = onFetched
        self.onSessionDeleted = onDeleted
    }

    func start() async {
        let config = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: loadPersistedState(),
            delegate: EngineDelegate(coordinator: self)
        )

        engine = CKSyncEngine(config)

        // Ensure zone exists
        do {
            let zone = CKRecordZone(zoneID: SessionRecordConverter.zoneID)
            try await database.save(zone)
            Log.sync.info("SyncCoordinator: Zone ready")
        } catch {
            Log.sync.info("SyncCoordinator: Zone setup: \(error.localizedDescription)")
        }
    }

    func save(_ record: CKRecord) {
        pendingRecords[record.recordID.recordName] = record
        engine?.state.add(pendingRecordZoneChanges: [
            .saveRecord(record.recordID)
        ])
    }

    func fetchChanges() async {
        do {
            try await engine?.fetchChanges()
        } catch {
            Log.sync.info("SyncCoordinator: Fetch error: \(error)")
        }
    }

    // MARK: - State persistence

    private func loadPersistedState() -> CKSyncEngine.State.Serialization? {
        guard let data = UserDefaults.standard.data(forKey: stateKey) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func persistState(_ serialization: CKSyncEngine.State.Serialization) {
        if let data = try? JSONEncoder().encode(serialization) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    // MARK: - Record provider

    private func recordToSave(for recordID: CKRecord.ID) -> CKRecord? {
        return pendingRecords[recordID.recordName]
    }

    // MARK: - Engine delegate

    private final class EngineDelegate: CKSyncEngineDelegate, @unchecked Sendable {
        private let coordinator: SyncCoordinator

        init(coordinator: SyncCoordinator) {
            self.coordinator = coordinator
        }

        func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) {
            Task {
                await coordinator.handleEvent(event, syncEngine: syncEngine)
            }
        }

        func nextRecordZoneChangeBatch(
            _ context: CKSyncEngine.SendChangesContext,
            syncEngine: CKSyncEngine
        ) async -> CKSyncEngine.RecordZoneChangeBatch? {
            let pending = syncEngine.state.pendingRecordZoneChanges

            return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: Array(pending)) { recordID in
                await coordinator.recordToSave(for: recordID)
            }
        }
    }

    private func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) {
        switch event {
        case .stateUpdate(let update):
            persistState(update.stateSerialization)

        case .fetchedRecordZoneChanges(let changes):
            for modification in changes.modifications {
                let record = modification.record
                guard record.recordType == SessionRecordConverter.recordType else { continue }
                if let session = SessionRecordConverter.session(from: record) {
                    let systemFields = SessionRecordConverter.encodeSystemFields(of: record)
                    onSessionFetched?(session, systemFields)
                }
            }
            for deletion in changes.deletions {
                onSessionDeleted?(deletion.recordID.recordName)
            }

        case .sentRecordZoneChanges(let sent):
            for saved in sent.savedRecords {
                pendingRecords.removeValue(forKey: saved.recordID.recordName)
                Log.sync.info("SyncCoordinator: Saved \(saved.recordID.recordName)")
            }
            for failed in sent.failedRecordSaves {
                pendingRecords.removeValue(forKey: failed.record.recordID.recordName)
                Log.sync.info("SyncCoordinator: Failed save \(failed.record.recordID.recordName): \(failed.error)")
            }

        case .accountChange(let change):
            Log.sync.info("SyncCoordinator: Account change: \(change)")

        default:
            break
        }
    }
}
