import Foundation

let VERSION = Version(major: 1, minor: 1, patch: 1)

public struct Version {
    public let major: UInt
    public let minor: UInt
    public let patch: UInt
}

extension Version: CustomStringConvertible {
    public var description: String {
        return "\(self.major).\(self.minor).\(self.patch)"
    }
}
