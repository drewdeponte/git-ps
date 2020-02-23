import Foundation

let VERSION = Version(major: 0, minor: 2, patch: 0)

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
