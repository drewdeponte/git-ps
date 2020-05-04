import Foundation

public final class GitPatchStack {
    public enum Error: Swift.Error {
        case invalidArgumentCount
        case commandFailed
        case patchConflict
    }

    private enum CommitRequestReviewStatus {
        case unrequested
        case requestedAndUnchangedSince
        case requestedAndChangedSince
        case published
    }

    private let arguments: [String]
    private let remote: String
    private let baseBranch: String

    private let git: GitShell

    private var remoteBase: String {
        return "\(self.remote)/\(self.baseBranch)"
    }

    public init(arguments: [String] = CommandLine.arguments, remote: String = "origin", baseBranch: String = "master") throws {
        self.arguments = arguments
        self.remote = remote
        self.baseBranch = baseBranch
        self.git = try GitShell(bash: Bash())
    }

    public func run() throws {

        guard self.arguments.count >= 2 else {
            throw Error.invalidArgumentCount
        }

        let subcommand = self.arguments[1]
        switch subcommand {
        case "ls":
            try self.list()
        case "show":
            guard self.arguments.count == 3 else {
                throw Error.invalidArgumentCount
            }

            if let index = Int(self.arguments[2]) {
                try self.show(patchIndex: index)
            } else {
                print("Usage: git-ps show <patch-index>")
                print("Note: Run 'git-ps ls' to see the current patches an their index values")
            }
        case "pull":
            try self.pull()
        case "rebase":
            try self.rebase()
        case "rr":
            guard self.arguments.count == 3 else {
                throw Error.invalidArgumentCount
            }

            if let index = Int(self.arguments[2]) {
                try self.requestReview(patchIndex: index)
            } else {
                print("Usage: git-ps rr <patch-index>")
                print("Note: Run 'git-ps ls' to see the current patches an their index values")
            }
        case "pub":
            if self.arguments.count == 3 { // git-ps pub <patch-index>
                if let index = Int(self.arguments[2]) {
                    try self.publish(patchIndex: index)
                } else {
                    print("Usage: git-ps pub [-f] <patch-index>")
                    print("Note: Run 'git-ps ls' to see the current patches an their index values")
                }
            } else if self.arguments.count == 4 { // git-ps pub -f <patch-index>
                if let index = Int(self.arguments[3]), self.arguments[2] == "-f"  {
                    try self.publish(patchIndex: index, force: true)
                } else {
                    print("Usage: git-ps pub [-f] <patch-index>")
                    print("Note: Run 'git-ps ls' to see the current patches an their index values")
                }
            } else {
                print("Usage: git-ps pub [-f] <patch-index>")
                print("Note: Run 'git-ps ls' to see the current patches an their index values")
            }
        case "--version":
            print("v\(VERSION)")
        case "--help", "-h":
            showHelpText()
        default:
            print("default")
        }
    }

    public func list() throws {
        guard let dotGitDirURL = try self.git.findDotGit() else {
            print("Error: doesn't seem like you are in a git repository")
            return
        }

        let rrRepository = try RequestReviewRepository(dirURL: dotGitDirURL)

        let patches = try self.patchStack()
        try patches.enumerated().reversed().forEach { (offset: Int, commitSummary: CommitSummary) in

            let abbrev = self.requestReviewStatusToAbbrev(try self.requestReviewStatus(commitSummary, requestReviewRepository: rrRepository))

            var offsetStr = "\(offset)"
            for _ in 0...(2 - offsetStr.count) {
                offsetStr = " \(offsetStr)"
            }
            print("\(offsetStr) \(abbrev) \(String(describing: commitSummary))")
        }
    }

    public func show(patchIndex: Int) throws {
        guard let patch = try self.getPatch(index: patchIndex) else {
            print("Error: there is no patch with an index of \(patchIndex)")
            return
        }

        self.git.show(commit: patch.sha)
    }

    public func pull() throws {
        guard let dotGitDirURL = try self.git.findDotGit() else {
            print("Error: doesn't seem like you are in a git repository")
            return
        }

        let rrRepository = try RequestReviewRepository(dirURL: dotGitDirURL)

        try self.git.fetch(remote: self.remote, branch: self.baseBranch)
        try self.git.rebase(onto: self.remoteBase, from: self.remoteBase, to: self.baseBranch)

        try self.cleanse(requestReviewRepository: rrRepository)
    }

    public func rebase() throws {
        try self.git.rebase(onto: self.remoteBase, from: self.remoteBase, to: self.baseBranch, interactive: true)
    }

    public func requestReview(patchIndex: Int) throws {
        guard let dotGitDirURL = try self.git.findDotGit() else {
            print("Error: doesn't seem like you are in a git repository")
            return
        }
        print("- found .git dir - \(dotGitDirURL.path)")

        let rrRepository = try RequestReviewRepository(dirURL: dotGitDirURL)
        print("- loaded request review state repository")

        guard let patch = try self.getPatch(index: patchIndex) else {
            print("Error: there is no patch with an index of \(patchIndex)")
            return
        }
        print("- fetched patch at index - \(patchIndex)")

        guard try !self.git.uncommittedChangePresent() else {
            print("Error: uncommited changes are present")
            print("Please commit or stash any uncommitted changes before running this command.")
            return
        }
        print("- verified no uncommited changes are present")

        let originalBranch = try self.git.getCheckedOutBranch()
        print("- identified originating branch - \(originalBranch)")

        if let uuid = try self.getId(patch: patch) {
            print("- parsed patch id (\(uuid.uuidString)) out of commit description")

            // Get branch name from records or generate one if can't find it
            var rrTmpBranch: String?
            if let rrRecord = rrRepository.fetch(uuid) {
                print("- found record in request review state repository for id - \(uuid.uuidString)")
                rrTmpBranch = rrRecord.branchName
                print("- using branch name from request review state repository record - \(rrTmpBranch!)")
            } else { // dealing with a commit with a patch stack id but no record
                print("- failed to find record in request review state repository for id - \(uuid.uuidString)")
                rrTmpBranch = "ps/rr/\(self.slug(patch: patch))"
                print("- generated slug based branch name - \(rrTmpBranch!)")
            }

            guard let rrBranch = rrTmpBranch else {
                return
            }

            let record = RequestReviewRecord(patchStackID: uuid, branchName: rrBranch, commitID: patch.sha, published: false)
            try rrRepository.record(record)
            print("- recorded patch id, branch name, and commit sha association in request review state repository")

            try self.createOrUpdateRequestReviewBranch(named: rrBranch, withCommit: patch.sha, fallbackBranchName: originalBranch)

            // push branch up to remote
            try self.git.forcePush(branch: rrBranch, upToRemote: self.remote, displayOutput: true)
            print("- force pushed \(rrBranch) up to \(self.remote)")

            // checkout original branch
            try self.git.checkout(ref: originalBranch)
            print("- checked out \(originalBranch) so you are where you started")
        } else {
            print("- failed to parse a patch id out of commit description")
            // add id to commit
            let newPatchID = UUID()
            let newPatch = try self.addIdTo(uuid: newPatchID, patch: patch)

            // generate branch name
            let rrBranch = "ps/rr/\(self.slug(patch: patch))"

            let record = RequestReviewRecord(patchStackID: newPatchID, branchName: rrBranch, commitID: newPatch.sha, published: false)
            try rrRepository.record(record)
            print("- recorded patch id, branch name, and commit sha association in request review state repository")

            try self.createOrUpdateRequestReviewBranch(named: rrBranch, withCommit: newPatch.sha, fallbackBranchName: originalBranch)

            // push branch up to remote
            try self.git.forcePush(branch: rrBranch, upToRemote: self.remote, displayOutput: true)
            print("- force pushed \(rrBranch) up to \(self.remote)")

            // checkout original branch
            try self.git.checkout(ref: originalBranch)
            print("- checked out \(originalBranch) so you are where you started")
        }
    }

    public func publish(patchIndex: Int, force: Bool = false) throws {
        guard let dotGitDirURL = try self.git.findDotGit() else {
            print("Error: doesn't seem like you are in a git repository")
            return
        }
        print("- found .git dir - \(dotGitDirURL.path)")

        let rrRepository = try RequestReviewRepository(dirURL: dotGitDirURL)
        print("- loaded request review state repository")

        guard let patch = try self.getPatch(index: patchIndex) else {
            print("Error: there is no patch with an index of \(patchIndex)")
            return
        }
        print("- fetched patch at index - \(patchIndex)")

        guard try !self.git.uncommittedChangePresent() else {
            print("Error: uncommited changes are present")
            print("Please commit or stash any uncommitted changes before running this command.")
            return
        }
        print("- verified no uncommited changes are present")

        let originalBranch = try self.git.getCheckedOutBranch()
        print("- identified originating branch - \(originalBranch)")

        if let uuid = try self.getId(patch: patch) {
            print("- parsed patch id (\(uuid.uuidString)) out of commit description")

            // Get branch name from records or generate one if can't find it
            var rrTmpBranch: String?
            if let rrRecord = rrRepository.fetch(uuid) {
                print("- found record in request review state repository for id - \(uuid.uuidString)")
                rrTmpBranch = rrRecord.branchName
                print("- using branch name from request review state repository record - \(rrTmpBranch!)")
            } else { // dealing with a commit with a patch stack id but no record
                print("- failed to find record in request review state repository for id - \(uuid.uuidString)")
                rrTmpBranch = "ps/rr/\(self.slug(patch: patch))"
                print("- generated slug based branch name - \(rrTmpBranch!)")
            }

            guard let rrBranch = rrTmpBranch else {
                return
            }

            try self.createOrUpdateRequestReviewBranch(named: rrBranch, withCommit: patch.sha, fallbackBranchName: originalBranch)

            // push branch up to remote
            try self.git.forcePush(branch: rrBranch, upToRemote: self.remote)
            print("- force pushed \(rrBranch) up to \(self.remote)")

            try self.git.push(localBranch: rrBranch, upToRemote: self.remote, remoteBranch: self.baseBranch)

            let record = RequestReviewRecord(patchStackID: uuid, branchName: rrBranch, commitID: patch.sha, published: true)
            try rrRepository.record(record)
            print("- recorded patch id, branch name, and commit sha association in request review state repository")

            // checkout original branch
            try self.git.checkout(ref: originalBranch)
            print("- checked out \(originalBranch) so you are where you started")

            try self.git.deleteRemoteBranch(named: rrBranch, remote: self.remote)

            try self.git.deleteBranch(named: rrBranch)
        } else {
            if force {
                print("- failed to parse a patch id out of commit description")
                // add id to commit
                let newPatchID = UUID()
                let newPatch = try self.addIdTo(uuid: newPatchID, patch: patch)

                // generate branch name
                let rrBranch = "ps/rr/\(self.slug(patch: patch))"

                try self.createOrUpdateRequestReviewBranch(named: rrBranch, withCommit: newPatch.sha, fallbackBranchName: originalBranch)

                // push branch up to remote
                try self.git.forcePush(branch: rrBranch, upToRemote: self.remote)
                print("- force pushed \(rrBranch) up to \(self.remote)")

                try self.git.push(localBranch: rrBranch, upToRemote: self.remote, remoteBranch: self.baseBranch)

                let record = RequestReviewRecord(patchStackID: newPatchID, branchName: rrBranch, commitID: newPatch.sha, published: true)
                try rrRepository.record(record)
                print("- recorded patch id, branch name, and commit sha association in request review state repository")

                // checkout original branch
                try self.git.checkout(ref: originalBranch)
                print("- checked out \(originalBranch) so you are where you started")

                try self.git.deleteRemoteBranch(named: rrBranch, remote: self.remote)

                try self.git.deleteBranch(named: rrBranch)
            } else {
                print("Looks like you haven't requested review for this patch yet. Please do so before publishing. If you want to publish without requesting review use 'git-ps pub -f'.")
            }
        }
    }

    private func patchStack() throws -> [CommitSummary] {
        let patches = try git.commits(from: self.remoteBase, to: self.baseBranch)
        return patches.reversed() // reverse so indexing is 0 closest to origin, u
    }

    private func getPatch(index: Int) throws -> CommitSummary? {
        let patches = try self.patchStack()
        guard (index >= 0) && (index < patches.count) else { return nil }
        return patches[index]
    }

    private func addIdTo(uuid: UUID, patch: CommitSummary) throws -> CommitSummary {
        let originalBranch = try self.git.getCheckedOutBranch()
        let commonAncestorRef = try self.git.mergeBase(refA: patch.sha, refB: self.remoteBase)
        try self.git.createAndCheckout(branch: "ps/tmp/add_id_rework", startingFrom: commonAncestorRef)
        try self.git.cherryPickCommits(from: commonAncestorRef, to: patch.sha)
        let shaOfPatchPrime = try self.git.getShaOf(ref: "HEAD")
        print("- got sha of HEAD (a.k.a. patch') - \(shaOfPatchPrime)")
        let originalMessage = try self.git.commitMessageOf(ref: shaOfPatchPrime)
        print("- got commit message from \(shaOfPatchPrime) (a.k.a. patch')")
        try self.git.commitAmendMessages(messages: [originalMessage, "ps-id: \(uuid.uuidString)"])
        print("- amended patch' wich ps-id: \(uuid.uuidString), it is now patch''")
        let shaOfPatchFinalPrime = try self.git.getShaOf(ref: "HEAD")
        print("- got sha of HEAD (a.k.a. patch'' - \(shaOfPatchFinalPrime)")
        try self.git.cherryPickCommits(from: patch.sha, to: self.baseBranch)
        try self.git.forceBranch(named: self.baseBranch, to: "HEAD")
        print("- forced branch (\(self.baseBranch)) to point to HEAD")
        try self.git.checkout(ref: originalBranch)
        print("- checked out branch - \(originalBranch)")
        try self.git.deleteBranch(named: "ps/tmp/add_id_rework")
        print("- deleted tmp working branch - ps/tmp/add_id_rework")
        return try self.git.commitSummary(shaOfPatchFinalPrime)
    }

    private func getId(patch: CommitSummary) throws -> UUID? {
        let message = try self.git.commitMessageOf(ref: patch.sha)
        let pattern = #"ps-id:\s(?<patchStackId>[\w\d-]+)"#
        let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let nsrange = NSRange(message.startIndex..<message.endIndex,
        in: message)
        if let match = regex.firstMatch(in: message, options: [], range: nsrange) {
            if let patchStackIdRange = Range(match.range(withName: "patchStackId"), in: message) {
                let patchStackIdStr = String(message[patchStackIdRange])
                return UUID(uuidString: patchStackIdStr)
            } else { // matched ps-id but failed to get the range of the capture group
                return nil
            }
        } else { // didn't find match
            return nil
        }
    }

    private func slug(patch: CommitSummary) -> String {
        return patch.summary.replaceCharactersFromSet(characterSet: CharacterSet.alphanumerics.inverted, replacementString: "_").lowercased()
    }

    private func createOrUpdateRequestReviewBranch(named branchName: String, withCommit commitRef: String, fallbackBranchName: String) throws {
        // Do this so that we are always creating PR branches on top of the latest remote baseBranch
        try self.git.fetch(remote: self.remote, branch: self.baseBranch)
        print("- fetched \(self.remoteBase)")

        // create the new request review branch on remote base
        try self.git.createBranch(named: branchName, on: self.remoteBase)
        print("- created branch (\(branchName)) on (\(self.remoteBase))")

        // checkout the new branch
        try self.git.checkout(ref: branchName)
        print("- checked out \(branchName)")

        do {
            print("- cherry picking commit - \(commitRef)")
            // cherry pick selected commit sha into branch
            try self.git.cherryPick(ref: commitRef)
            print("- successfully cherry picked commit - \(commitRef)")
        } catch GitShell.Error.gitCherryPickFailure {
            print("Looks like you are trying to request review of a patch that conflicts with \(self.remoteBase). It could be that it is dependent on another patch that is NOT currently in \(self.remoteBase) or just be conflicting with recent changes to \(self.remoteBase).  Dependent patches MUST be in \(self.remoteBase) before requesting review of patches that depend on them.\n")

            // cherry pick abort
            try self.git.cherryPickAbort()
            print("- Aborted cherry pick")

            // checkout original branch
            try self.git.checkout(ref: fallbackBranchName)
            print("- Checked out \(fallbackBranchName) so you are left off where you started")

            // exit with error
            throw Error.patchConflict
        }
    }

    private func requestReviewStatus(_ commitSummary: CommitSummary, requestReviewRepository: RequestReviewRepository) throws -> CommitRequestReviewStatus {

        if let id = try self.getId(patch: commitSummary) {
            // have requested
            if let record = requestReviewRepository.fetch(id) {
                if let published = record.published {
                    if published {
                        return .published
                    } else {
                        if record.commitID == commitSummary.sha  {
                            return .requestedAndUnchangedSince
                        } else {
                            return .requestedAndChangedSince
                        }
                    }
                } else {
                    if record.commitID == commitSummary.sha  {
                        return .requestedAndUnchangedSince
                    } else {
                        return .requestedAndChangedSince
                    }
                }
            } else {
                return .unrequested
            }
        } else {
            return .unrequested
        }
    }

    private func requestReviewStatusToAbbrev(_ requestReviewStatus: CommitRequestReviewStatus) -> String {
        switch requestReviewStatus {
        case .unrequested: return "   "
        case .requestedAndUnchangedSince: return "rr "
        case .requestedAndChangedSince: return "rr+"
        case .published: return "  p"
        }
    }

    private func cleanse(requestReviewRepository: RequestReviewRepository) throws {

        let requestReviewRecords = requestReviewRepository.all

        let matchedPatches = try self.patchStack().reduce(into: Dictionary<UUID, CommitSummary>()) { (patches, commitSummary) in
            if let id = try self.getId(patch: commitSummary) {
                patches[id] = commitSummary
            }
        }

        try requestReviewRecords.forEach { (patchStackID: UUID, requestReviewRecord: RequestReviewRecord) in

            if matchedPatches[patchStackID] == nil {
                try requestReviewRepository.removeRecord(withPatchStackID: patchStackID)
            }
        }
    }

    private func showHelpText() {
        let text = """
            usage: git-ps <command> [<patch-index>]

            Commands:
              ls             List the stack of patches
              show <i>       Show the patch diff and details
              pull           Fetch the state of origin/master and rebase the stack of patches onto it
              reabase        Interactive rebase the stack of patches
              rr <i>         Request review of the patch or update existing request to review
              pub <i>        Publish a patch into upstream's mainline (aka origin/master)
              --version      Output the version of information for reference & bug reporting
              --help, -h     Show help information

            git-ps ls result structure:
              [patch-index] [review status] [commit short sha] [commit summary]
              "0  rr  788032 Update README with deployment instructions"

            git-ps ls Review Status:
                    Has NOT requested a review (AKA Empty)
              rr    Requested a review and it's unchanged since requesting
              rr+   Requested a review and it has changed since requesting
              p     Commit has been published to origin/master
            """
        print(text)
    }
}

extension String {
  func replaceCharactersFromSet(characterSet: CharacterSet, replacementString: String = "") -> String {
    return self.components(separatedBy: characterSet).joined(separator: replacementString)
  }
}
