import Foundation
import JsonFileManager

class RequestReviewRepository {
    private let fileURL: URL
    private typealias RequestReviewRecordsCache = Dictionary<UUID, RequestReviewRecord>
    private let fileManager: JsonFileManager<RequestReviewRecordsCache>
    private var requestedReviewRecords: RequestReviewRecordsCache = [:]

    public init(dirURL: URL) throws {
        self.fileURL = dirURL.appendingPathComponent("patch-stack-review-requests.json")
        self.fileManager = JsonFileManager<RequestReviewRecordsCache>(fileURL: self.fileURL)
        try fileManager.read { [weak self] (records) in
            self?.requestedReviewRecords.merge(records, uniquingKeysWith: { (origRecord, newRecord) -> RequestReviewRecord in
                return newRecord
            })
        }
    }

    public func record(_ requestReviewRecord: RequestReviewRecord) throws {
        self.requestedReviewRecords[requestReviewRecord.patchStackID] = requestReviewRecord
        try self.fileManager.save(data: self.requestedReviewRecords)
    }

    public func fetch(_ patchStackID: UUID) -> RequestReviewRecord? {
        return self.requestedReviewRecords[patchStackID]
    }
}
