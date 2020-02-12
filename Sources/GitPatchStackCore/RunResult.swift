import Foundation

public struct RunResult {
    let standardOutput: String?
    let standardError: String?
    let terminationStatus: Int32

    public var isSuccessful: Bool {
        self.terminationStatus == 0
    }
}

extension RunResult: CustomStringConvertible {
    public var description: String {
        return "stdout: \(String(describing: standardOutput))\nstderr: \(String(describing: standardError))\nterminationStatus: \(terminationStatus)"
    }
}
