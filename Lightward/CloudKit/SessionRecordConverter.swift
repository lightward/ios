import CloudKit
import Foundation

/// Converts between Session and CKRecord.
/// Single record type "Session" with JSON-embedded messages.
enum SessionRecordConverter {
    static let recordType = "Session"
    static let zoneID = CKRecordZone.ID(zoneName: "LightwardZone", ownerName: CKCurrentUserDefaultName)

    // MARK: - Session → CKRecord

    static func record(from session: Session, existingSystemFields: Data? = nil) -> CKRecord {
        let record: CKRecord
        if let systemFields = existingSystemFields {
            record = Self.record(fromSystemFields: systemFields, recordName: session.id.uuidString)
        } else {
            let recordID = CKRecord.ID(recordName: session.id.uuidString, zoneID: zoneID)
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        record["phoropterTrailJSON"] = (try? encoder.encode(session.phoropterTrail))
            .flatMap { String(data: $0, encoding: .utf8) } as CKRecordValue?
        record["chatMessagesJSON"] = (try? encoder.encode(session.chatMessages))
            .flatMap { String(data: $0, encoding: .utf8) } as CKRecordValue?
        record["createdDate"] = session.created as CKRecordValue
        record["modifiedDate"] = session.modified as CKRecordValue

        return record
    }

    // MARK: - CKRecord → Session

    static func session(from record: CKRecord) -> Session? {
        guard let idString = record.recordID.recordName as String?,
              let id = UUID(uuidString: idString) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let trail: [String] = {
            guard let json = record["phoropterTrailJSON"] as? String,
                  let data = json.data(using: .utf8),
                  let decoded = try? decoder.decode([String].self, from: data) else {
                return []
            }
            return decoded
        }()

        let messages: [ChatMessage] = {
            guard let json = record["chatMessagesJSON"] as? String,
                  let data = json.data(using: .utf8),
                  let decoded = try? decoder.decode([ChatMessage].self, from: data) else {
                return []
            }
            return decoded
        }()

        let created = record["createdDate"] as? Date ?? record.creationDate ?? Date()
        let modified = record["modifiedDate"] as? Date ?? record.modificationDate ?? Date()

        var session = Session()
        session = Session(id: id, phoropterTrail: trail, chatMessages: messages, created: created, modified: modified)
        return session
    }

    // MARK: - System fields

    static func encodeSystemFields(of record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    static func record(fromSystemFields data: Data, recordName: String) -> CKRecord {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data),
              let record = CKRecord(coder: coder) else {
            let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
            return CKRecord(recordType: recordType, recordID: recordID)
        }
        coder.finishDecoding()
        return record
    }
}
