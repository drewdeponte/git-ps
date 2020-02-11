import Foundation

public struct Patch {
    public let sha: String
    public let summary: String
}

extension Patch: CustomStringConvertible {
    public var description: String {
        return "\(self.sha) \(self.summary)"
    }
}

public class GitShell {
    private let path: String
    private let remote: String
    private let baseBranch: String
    private var remoteBase: String {
        return "\(self.remote)/\(self.baseBranch)"
    }

    public init(bash: Bash, path: String? = nil, remote: String = "origin", baseBranch: String = "master") throws {
        if let p = path {
            self.path = p
        } else {
            self.path = try bash.which("git")
        }
        self.remote = remote
        self.baseBranch = baseBranch
    }

    public func patchStack() throws -> [Patch] {
        let result = try run(self.path, arguments: ["log", "--pretty=%C(auto)%H %s", "\(self.remoteBase)..\(self.baseBranch)"])
        if let output = result.standardOutput {
            let lines = output.split { $0.isNewline }

            return lines.map { (line) -> Patch in
                let firstSpace = line.firstIndex(of: " ")!
                let sha = String(line.prefix(upTo: firstSpace))
                let summary = line.suffix(from: firstSpace).trimmingCharacters(in: .whitespacesAndNewlines)
                return Patch(sha: sha, summary: summary)
            }
        }
        return []
    }

    public func foo() {
        print("path: \(self.path)")
    }
}
