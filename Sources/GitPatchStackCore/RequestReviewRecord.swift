import Foundation

struct RequestReviewRecord: Codable {
    let patchStackID: UUID
    let branchName: String
    let commitID: String
}
