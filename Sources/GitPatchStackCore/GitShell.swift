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
        case gitCreateAndCheckoutFailure
        case gitCherryPickCommitsFailure
        case gitShaOfFailure
        case gitCommitMessageOfFailure
        case gitCommitAmendMessages
        case gitRevListFailure
        case gitForceBranchFailure
        case gitDeleteBranchFailure
        case gitCheckoutFailure
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

    public func createAndCheckout(branch: String, startingFrom: String, tracking: Bool = false) throws {
        var result: RunResult?
        if tracking == true {
            result = try run(self.path, arguments: ["checkout", "-B", branch, "--track", startingFrom])
        } else {
            result = try run(self.path, arguments: ["checkout", "-B", branch, "--no-track", startingFrom])
        }

        guard let res = result, res.isSuccessful == true else {
            throw Error.gitCreateAndCheckoutFailure
        }
    }

    public func cherryPickCommits(from: String, to: String) throws {
        print("DREW: cherry picking from \(from)..\(to)")
        let result = try run(self.path, arguments: ["cherry-pick", "\(from)..\(to)"])
        guard result.isSuccessful == true else {
            if let errOutput = result.standardOutput {
                print(errOutput)
            }
            throw Error.gitCherryPickCommitsFailure
        }
    }

    public func getShaOf(ref: String) throws -> String {
        let result = try run(self.path, arguments: ["rev-list", "-n1", ref])
        guard result.isSuccessful == true else {
            throw Error.gitShaOfFailure
        }

        guard let output = result.standardOutput else {
            throw Error.gitShaOfFailure
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func commitMessageOf(ref: String) throws -> String {
        let result = try run(self.path, arguments: ["rev-list", "--format=%B", "--max-count=1", ref])
        guard result.isSuccessful == true else {
            throw Error.gitCommitMessageOfFailure
        }

        guard let output = result.standardOutput else {
            throw Error.gitCommitMessageOfFailure
        }

        if let firstNewlineIndex = output.firstIndex(of: "\n") {
            var out = output
            out.removeSubrange(...firstNewlineIndex)
            return out
        } else {
            throw Error.gitCommitMessageOfFailure
        }
    }

    public func commitAmendMessages(messages: [String]) throws {
        var args = ["commit", "--amend"]
        for msg in messages {
            args.append("-m")
            args.append(msg)
        }
        let result = try run(self.path, arguments: args)
        guard result.isSuccessful == true else {
            throw Error.gitCommitMessageOfFailure
        }
    }

    public func revList(from: String, to: String) throws -> [String] {
        let result = try run(self.path, arguments: ["rev-list", "\(from)..\(to)"])
        guard result.isSuccessful == true else {
            throw Error.gitRevListFailure
        }

        guard let output = result.standardOutput else {
            throw Error.gitRevListFailure
        }

        return output.split(separator: "\n").map { String($0) }
    }

    public func forceBranch(named: String, to: String) throws {
        let result = try run(self.path, arguments: ["branch", "-f", named, to])
        guard result.isSuccessful == true else {
            throw Error.gitForceBranchFailure
        }
    }

    public func deleteBranch(named: String) throws {
        let result = try run(self.path, arguments: ["branch", "-D", named])
        guard result.isSuccessful == true else {
            throw Error.gitDeleteBranchFailure
        }
    }

    public func checkout(ref: String) throws {
        let result = try run(self.path, arguments: ["checkout", ref])
        guard result.isSuccessful == true else {
            throw Error.gitCheckoutFailure
        }
    }
}
