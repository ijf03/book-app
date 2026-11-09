import Foundation
import FirebaseFirestore

nonisolated enum FirestoreRecordMapper {
    static func decode(collection: SyncCollection, documentID: String, fields: [String: Any]) throws -> CloudRecord {
        guard let schema = fields["schemaVersion"] as? Int, schema == 1,
              let identity = fields["entityID"] as? String,
              CloudRecord.documentID(for: identity) == documentID,
              let revision = fields["revision"] as? Int, revision > 0,
              let operationID = fields["operationID"] as? String, !operationID.isEmpty,
              let deleted = fields["deleted"] as? Bool,
              let payload = fields["data"] as? [String: Any],
              fields["updatedAt"] is Timestamp else { throw SyncFailure.malformed }
        let data = deleted ? nil : try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return CloudRecord(collection: collection, entityID: identity, revision: revision,
                           operationID: operationID, payload: data)
    }

    static func encode(_ record: CloudRecord) throws -> [String: Any] {
        let payload: [String: Any]
        if let data = record.payload {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw SyncFailure.malformed }
            payload = object
        } else { payload = [:] }
        return [
            "schemaVersion": record.schemaVersion,
            "entityID": record.entityID,
            "revision": record.revision,
            "operationID": record.operationID,
            "deleted": record.isDeleted,
            "data": payload,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}
