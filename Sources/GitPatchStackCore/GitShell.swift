import Foundation

public struct CommitSummary {
    public let sha: String
    public let summary: String
}

extension CommitSummary: CustomStringConvertible {
    public var description: String {
        return "\(self.sha.prefix(6)) \(self.summary)"
    }
}

public class GitShell {
    public enum Error: Swift.Error {
        case gitLogFailure
        case gitFetchFailure
        case gitRebaseFailure
        case gitUncommittedChangePresentFailure
        case gitCheckedOutBranchFailure
    }

    private let path: String

    public init(bash: Bash, path: String? = nil) throws {
        if let p = path {
            self.path = p
        } else {
            self.path = try bash.which("git")
        }
    }

    public func commits(from fromRef: String, to toRef: String) throws -> [CommitSummary] {
        let result = try run(self.path, arguments: ["log", "--pretty=%H %s", "\(fromRef)..\(toRef)"])
        guard result.isSuccessful else { throw Error.gitLogFailure }

        if let output = result.standardOutput {
            let lines = output.split { $0.isNewline }

            return lines.map { (line) -> CommitSummary in
                let firstSpace = line.firstIndex(of: " ")!
                let sha = String(line.prefix(upTo: firstSpace))
                let summary = line.suffix(from: firstSpace).trimmingCharacters(in: .whitespacesAndNewlines)
                return CommitSummary(sha: sha, summary: summary)
            }
        }
        return []
    }

    public func fetch(remote: String, branch: String) throws {
        let result = try run(self.path, arguments: ["fetch", "--quiet", remote, branch])
        guard result.isSuccessful else {
            throw Error.gitFetchFailure
        }
    }

    public func show(commit: String) {
        replaceProcess(self.path, command: "git", arguments: ["show", "--pretty=raw", commit])
    }

    public func rebase(onto: String, from: String, to: String, interactive: Bool = false) throws {
        if interactive {
            replaceProcess(self.path, command: "git", arguments: ["rebase", "-i", "--onto", onto, from, to])
        } else {
            let result = try run(self.path, arguments: ["rebase", "--onto", onto, from, to])
            guard result.isSuccessful else {
                throw Error.gitRebaseFailure
            }
        }
    }

    public func uncommittedChangePresent() throws -> Bool {
        let result = try run(self.path, arguments: ["status", "--porcelain"])
        guard result.isSuccessful else {
            throw Error.gitUncommittedChangePresentFailure
        }

        guard let output = result.standardOutput else {
            throw Error.gitUncommittedChangePresentFailure
        }

        if output == "" {
            return false
        } else {
            return true
        }
    }

    public func getCheckedOutBranch() throws -> String {
        let result = try run(self.path, arguments: ["rev-parse", "--abbrev-ref", "HEAD"])
        guard result.isSuccessful else {
            throw Error.gitCheckedOutBranchFailure
        }

        guard let output = result.standardOutput else {
            throw Error.gitCheckedOutBranchFailure
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
