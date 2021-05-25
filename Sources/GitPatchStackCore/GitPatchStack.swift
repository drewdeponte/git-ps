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

    private let git: GitShell

    public init(arguments: [String] = CommandLine.arguments) throws {
        self.arguments = arguments
        self.git = try GitShell(bash: Bash())
    }

    public func run() throws {
        guard let cmd = parseCommand(self.arguments) else { showHelpText(); throw Error.invalidArgumentCount }
        switch cmd {
        case .help:
            showHelpText()
        case .version:
            print("v\(VERSION)")
        case .list:
            try self.list()
        case .pull:
            try self.pull()
        case .rebase:
            try self.rebase()
        case .show(args: let args):
            guard let (patchIndex, options) = parseShowSubcommand(args) else { print(showSubCommandHelpText());  throw Error.invalidArgumentCount }
            guard !options.contains(.help) else { print(showSubCommandHelpText());  throw Error.invalidArgumentCount }
            try self.show(patchIndex: patchIndex)
        case .requestReview(args: let args):
            guard let (patchIndexRange, options) = parseRequestReviewSubcommand(args) else { print(requestReviewSubCommandHelpText()); throw Error.invalidArgumentCount }
            guard !options.contains(.help) else { print(requestReviewSubCommandHelpText()); throw Error.invalidArgumentCount }

            let branchName = options.compactMap { $0.branchName }.first

            if patchIndexRange.isSingular {
                try self.requestReview(patchIndex: patchIndexRange.startIndex, reviewBranchName: branchName)
            } else {
                try self.requestReviewPatchSeries(patchIndexRange: patchIndexRange, reviewBranchName: branchName)
            }

        case .publish(args: let args):
            guard let (patchIndex, options) = parsePublishSubcommand(args) else { print(publishSubCommandHelpText()); throw Error.invalidArgumentCount }
            guard !options.contains(.help) else { print(publishSubCommandHelpText());  throw Error.invalidArgumentCount }

            let force = options.contains(where: { $0 == .force })
            let keep = options.contains(where: { $0 == .keep })
            let branchName = options.compactMap { $0.branchName }.first

            try self.publish(patchIndex: patchIndex, force: force, reviewBranchName: branchName, keepRemoteBranch: keep)
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

        let currentBranch = try self.git.getCheckedOutBranch()
        let upstreamBranch = try self.git.getUpstreamBranch()

        try self.git.fetch(remote: upstreamBranch.remote, branch: upstreamBranch.branch)
        try self.git.rebase(onto: upstreamBranch.remoteBase, from: upstreamBranch.remoteBase, to: currentBranch)

        try self.cleanse(requestReviewRepository: rrRepository)
    }

    public func rebase() throws {
        let currentBranch = try self.git.getCheckedOutBranch()
        let upstreamBranch = try self.git.getUpstreamBranch()
        try self.git.rebase(onto: upstreamBranch.remoteBase, from: upstreamBranch.remoteBase, to: currentBranch, interactive: true)
    }

    func attempt<A>(_ f: () throws -> A?, onSuccess: ((A) throws -> Void)? = nil, fallback g: () throws -> A) throws -> A {
        print("Inside the attempt()")
        if let fValue = try f() {
            print("f() return an fValue")
            if let suc = onSuccess {
                print("have an onSuccess handler")
                try suc(fValue)
                print("executed the onSuccess handler")
                return fValue
            } else {
                print("don't have an onSuccess handler")
                return fValue
            }
        } else {
            print("f() return nil")
            return try g()
        }
    }

    func commitSummary(from commit: Commit) -> CommitSummary {
        return CommitSummary(sha: commit.hash, summary: commit.summary)
    }

    func getPatchInfo(forRange patchIndexRange: PatchIndexRange) throws -> [(patch: Commit, patchId: UUID?)] {
        var patchInfo: [(patch: Commit, patchId: UUID?)] = []
        try (patchIndexRange.startIndex...patchIndexRange.endIndex).forEach { idx in
            guard let curPatch = try self.iteratorGetPatch(index: idx) else {
                print("Error: there is no patch with an index of \(idx)")
                throw Error.commandFailed
            }
            print("- fetched patch at idx - \(idx)")

            if let curPatchId = try? self.getId(patch: commitSummary(from: curPatch)) {
                patchInfo.append((patch: curPatch, patchId: curPatchId))
            } else {
                patchInfo.append((patch: curPatch, patchId: nil))
            }
        }
        return patchInfo
    }

    public func requestReviewPatchSeries(patchIndexRange: PatchIndexRange, reviewBranchName: String? = nil) throws {
        guard let dotGitDirURL = try self.git.findDotGit() else {
            print("Error: doesn't seem like you are in a git repository")
            return
        }
        print("- found .git dir - \(dotGitDirURL.path)")

        let rrRepository = try RequestReviewRepository(dirURL: dotGitDirURL)
        print("- loaded request review state repository")

        guard try !self.git.uncommittedChangePresent() else {
            print("Error: uncommited changes are present")
            print("Please commit or stash any uncommitted changes before running this command.")
            return
        }
        print("- verified no uncommited changes are present")

        guard patchIndexRange.endIndex > patchIndexRange.startIndex else {
            print("Error: invalid patch index range - \(patchIndexRange)")
            return
        }

        let patchInfo = try getPatchInfo(forRange: patchIndexRange)

        guard patchInfo.count >= 2 else {
            print("Error: couldn't identify patch series properly.")
            return
        }

        let originalBranch = try self.git.getCheckedOutBranch()
        print("- identified originating branch - \(originalBranch)")

        let upstreamBranch = try self.git.getUpstreamBranch()

        let requestReviewRecords = patchInfo.compactMap { $0.patchId }.compactMap { rrRepository.fetch($0) }

        guard requestReviewRecords.count < 2 || reviewBranchName != nil else {
            print(requestReviewSubCommandHelpText())
            print("\nError: explict branch specification (-n <branch-name>) required when multiple patches already have branch associations.")
            exit(1)
        }

        guard let origStartPatchInfo = patchInfo.first else {
            print(requestReviewSubCommandHelpText())
            print("\nError: no starting patch found")
            exit(1)
        }

        if requestReviewRecords.isEmpty { // - none of the patches are associated with a branch
            // associate branch to first patch
            print("- failed to find a record for any of the patches")

            let branchName = try attempt({
                reviewBranchName
            }, onSuccess: {
                print("- explicit review branch name provided - \($0)")
            }, fallback: {
                let bn = "ps/rr/\(self.slug(patch: commitSummary(from: patchInfo.first!.patch)))"
                print("- generated slug based branch name - \(bn)")
                return bn
            })

            var startPatchInfo: (patch: Commit, patchId: UUID)?

            if let tmpStartPatchInfo = origStartPatchInfo.patchId.map({ (patch: origStartPatchInfo.patch, patchId: $0) }) {
                startPatchInfo = tmpStartPatchInfo
            } else {
                let newPatchId = UUID()
                let newPatch = try self.addIdTo(uuid: newPatchId, patch: origStartPatchInfo.patch)!
                startPatchInfo = (patch: newPatch, patchId: newPatchId)
            }

            let postAddIdPatchInfo = try getPatchInfo(forRange: patchIndexRange)
            let endPatchInfo = postAddIdPatchInfo.last!

            let record = RequestReviewRecord(patchStackID: startPatchInfo!.patchId, branchName: branchName, commitID: startPatchInfo!.patch.hash, published: false)
            try rrRepository.record(record)
            print("- recorded patch id, branch name, and commit sha association in request review state repository")

            try self.createOrUpdateRequestReviewBranch(named: branchName, fromCommit: startPatchInfo!.patch.parentHash, toCommit: endPatchInfo.patch.hash, fallbackBranchName: originalBranch)

            // push branch up to remote
            try self.git.forcePush(branch: branchName, upToRemote: upstreamBranch.remote, displayOutput: true)
            print("- force pushed \(branchName) up to \(upstreamBranch.remote)")

            // checkout original branch
            try self.git.checkout(ref: originalBranch)
            print("- checked out \(originalBranch) so you are where you started")
        } else if requestReviewRecords.count == 1 { // - exactly one patch is associated with a branch
            let requestReviewRecord = requestReviewRecords.first!

            // already have an association of branch via requestReviewRecord
            let branchName = try attempt({
                reviewBranchName
            }, onSuccess: {
                print("- explicit review branch name provided - \($0)")
            }, fallback: {
                print("- using previously associated branch - \(requestReviewRecord.branchName)")
                return requestReviewRecord.branchName
            })

            let matchPatchInfo = patchInfo.first { (patch: Commit, patchId: UUID?) in
                patchId == requestReviewRecord.patchStackID
            }
            let record = RequestReviewRecord(patchStackID: requestReviewRecord.patchStackID, branchName: branchName, commitID: matchPatchInfo!.patch.hash, published: false)
            try rrRepository.record(record)
            print("- recorded patch id, branch name, and commit sha association in request review state repository")

            let endPatchInfo = patchInfo.last!
            try self.createOrUpdateRequestReviewBranch(named: branchName, fromCommit: origStartPatchInfo.patch.parentHash, toCommit: endPatchInfo.patch.hash, fallbackBranchName: originalBranch)

            // push branch up to remote
            try self.git.forcePush(branch: branchName, upToRemote: upstreamBranch.remote, displayOutput: true)
            print("- force pushed \(branchName) up to \(upstreamBranch.remote)")

            // checkout original branch
            try self.git.checkout(ref: originalBranch)
            print("- checked out \(originalBranch) so you are where you started")
        } else { // Multiple patches with previous branch associations - not saving record association
            let branchName = reviewBranchName!

            let endPatchInfo = patchInfo.last!
            try self.createOrUpdateRequestReviewBranch(named: branchName, fromCommit: origStartPatchInfo.patch.parentHash, toCommit: endPatchInfo.patch.hash, fallbackBranchName: originalBranch)

            // push branch up to remote
            try self.git.forcePush(branch: branchName, upToRemote: upstreamBranch.remote, displayOutput: true)
            print("- force pushed \(branchName) up to \(upstreamBranch.remote)")

            // checkout original branch
            try self.git.checkout(ref: originalBranch)
            print("- checked out \(originalBranch) so you are where you started")
        }
    }

    public func requestReview(patchIndex: Int, reviewBranchName: String? = nil) throws {
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

        let upstreamBranch = try self.git.getUpstreamBranch()

        if let uuid = try self.getId(patch: patch) {
            print("- parsed patch id (\(uuid.uuidString)) out of commit description")

            // Get branch name from records or generate one if can't find it
            var rrTmpBranch: String?
            if let rrRecord = rrRepository.fetch(uuid) {
                print("- found record in request review state repository for id - \(uuid.uuidString)")
                if let explicitBranchName = reviewBranchName {
                    print("- explicit review branch name provided - \(explicitBranchName)")
                    print("- ignored previously stored branch name in favor of explicit review branch name")
                    rrTmpBranch = explicitBranchName
                } else {
                    rrTmpBranch = rrRecord.branchName
                    print("- using branch name from request review state repository record - \(rrTmpBranch!)")
                }
            } else { // dealing with a commit with a patch stack id but no record
                print("- failed to find record in request review state repository for id - \(uuid.uuidString)")
                if let explicitBranchName = reviewBranchName {
                    print("- explicit review branch name provided - \(explicitBranchName)")
                    rrTmpBranch = explicitBranchName
                } else {
                    rrTmpBranch = "ps/rr/\(self.slug(patch: patch))"
                    print("- generated slug based branch name - \(rrTmpBranch!)")
                }
            }

            guard let rrBranch = rrTmpBranch else {
                return
            }

            let record = RequestReviewRecord(patchStackID: uuid, branchName: rrBranch, commitID: patch.sha, published: false)
            try rrRepository.record(record)
            print("- recorded patch id, branch name, and commit sha association in request review state repository")

            try self.createOrUpdateRequestReviewBranch(named: rrBranch, withCommit: patch.sha, fallbackBranchName: originalBranch)

            // push branch up to remote
            try self.git.forcePush(branch: rrBranch, upToRemote: upstreamBranch.remote, displayOutput: true)
            print("- force pushed \(rrBranch) up to \(upstreamBranch.remote)")

            // checkout original branch
            try self.git.checkout(ref: originalBranch)
            print("- checked out \(originalBranch) so you are where you started")
        } else {
            print("- failed to parse a patch id out of commit description")
            // add id to commit
            let newPatchID = UUID()
            let newPatch = try self.addIdTo(uuid: newPatchID, patch: patch)

            // generate branch name
            var rrTmpBranch: String?
            if let explicitBranchName = reviewBranchName {
                print("- explicit review branch name provided - \(explicitBranchName)")
                rrTmpBranch = explicitBranchName
            } else {
                rrTmpBranch = "ps/rr/\(self.slug(patch: patch))"
                print("- generated slug based branch name - \(rrTmpBranch!)")
            }

            guard let rrBranch = rrTmpBranch else {
                return
            }

            let record = RequestReviewRecord(patchStackID: newPatchID, branchName: rrBranch, commitID: newPatch.sha, published: false)
            try rrRepository.record(record)
            print("- recorded patch id, branch name, and commit sha association in request review state repository")

            try self.createOrUpdateRequestReviewBranch(named: rrBranch, withCommit: newPatch.sha, fallbackBranchName: originalBranch)

            // push branch up to remote
            try self.git.forcePush(branch: rrBranch, upToRemote: upstreamBranch.remote, displayOutput: true)
            print("- force pushed \(rrBranch) up to \(upstreamBranch.remote)")

            // checkout original branch
            try self.git.checkout(ref: originalBranch)
            print("- checked out \(originalBranch) so you are where you started")
        }
    }

    public func publish(patchIndex: Int, force: Bool = false, reviewBranchName: String? = nil, keepRemoteBranch: Bool = false) throws {
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

        let upstreamBranch = try self.git.getUpstreamBranch()

        if let uuid = try self.getId(patch: patch) {
            print("- parsed patch id (\(uuid.uuidString)) out of commit description")

            // Get branch name from records or generate one if can't find it
            var rrTmpBranch: String?
            if let rrRecord = rrRepository.fetch(uuid) {
                print("- found record in request review state repository for id - \(uuid.uuidString)")
                if let explicitBranchName = reviewBranchName {
                    print("- explicit review branch name provided - \(explicitBranchName)")
                    print("- ignored previously stored branch name in favor of explicit review branch name")
                    rrTmpBranch = explicitBranchName
                } else {
                    rrTmpBranch = rrRecord.branchName
                    print("- using branch name from request review state repository record - \(rrTmpBranch!)")
                }
            } else { // dealing with a commit with a patch stack id but no record
                print("- failed to find record in request review state repository for id - \(uuid.uuidString)")
                if let explicitBranchName = reviewBranchName {
                    print("- explicit review branch name provided - \(explicitBranchName)")
                    rrTmpBranch = explicitBranchName
                } else {
                    rrTmpBranch = "ps/rr/\(self.slug(patch: patch))"
                    print("- generated slug based branch name - \(rrTmpBranch!)")
                }
            }

            guard let rrBranch = rrTmpBranch else {
                return
            }

            try self.createOrUpdateRequestReviewBranch(named: rrBranch, withCommit: patch.sha, fallbackBranchName: originalBranch)

            // push branch up to remote
            try self.git.forcePush(branch: rrBranch, upToRemote: upstreamBranch.remote)
            print("- force pushed \(rrBranch) up to \(upstreamBranch.remote)")

            try self.git.push(localBranch: rrBranch, upToRemote: upstreamBranch.remote, remoteBranch: upstreamBranch.branch)

            let record = RequestReviewRecord(patchStackID: uuid, branchName: rrBranch, commitID: patch.sha, published: true)
            try rrRepository.record(record)
            print("- recorded patch id, branch name, and commit sha association in request review state repository")

            // checkout original branch
            try self.git.checkout(ref: originalBranch)
            print("- checked out \(originalBranch) so you are where you started")

            if !keepRemoteBranch {
                try self.git.deleteRemoteBranch(named: rrBranch, remote: upstreamBranch.remote)
            }

            try self.git.deleteBranch(named: rrBranch)
        } else {
            if force {
                print("- failed to parse a patch id out of commit description")
                // add id to commit
                let newPatchID = UUID()
                let newPatch = try self.addIdTo(uuid: newPatchID, patch: patch)

                // generate branch name
                var rrTmpBranch: String?
                if let explicitBranchName = reviewBranchName {
                    print("- explicit review branch name provided - \(explicitBranchName)")
                    rrTmpBranch = explicitBranchName
                } else {
                    rrTmpBranch = "ps/rr/\(self.slug(patch: patch))"
                    print("- generated slug based branch name - \(rrTmpBranch!)")
                }

                guard let rrBranch = rrTmpBranch else {
                    return
                }

                try self.createOrUpdateRequestReviewBranch(named: rrBranch, withCommit: newPatch.sha, fallbackBranchName: originalBranch)

                // push branch up to remote
                try self.git.forcePush(branch: rrBranch, upToRemote: upstreamBranch.remote)
                print("- force pushed \(rrBranch) up to \(upstreamBranch.remote)")

                try self.git.push(localBranch: rrBranch, upToRemote: upstreamBranch.remote, remoteBranch: upstreamBranch.branch)

                let record = RequestReviewRecord(patchStackID: newPatchID, branchName: rrBranch, commitID: newPatch.sha, published: true)
                try rrRepository.record(record)
                print("- recorded patch id, branch name, and commit sha association in request review state repository")

                // checkout original branch
                try self.git.checkout(ref: originalBranch)
                print("- checked out \(originalBranch) so you are where you started")

                if !keepRemoteBranch {
                    try self.git.deleteRemoteBranch(named: rrBranch, remote: upstreamBranch.remote)
                }

                try self.git.deleteBranch(named: rrBranch)
            } else {
                print("Looks like you haven't requested review for this patch yet. Please do so before publishing. If you want to publish without requesting review use 'git-ps pub -f'.")
            }
        }
    }

    private func patchStack() throws -> [CommitSummary] {
        let currentBranch = try self.git.getCheckedOutBranch()
        let upstreamBranch = try self.git.getUpstreamBranch()

        let patches = try git.commits(from: upstreamBranch.remoteBase, to: currentBranch)
        return patches.reversed() // reverse so indexing is 0 closest to origin, u
    }

    private func iteratorPatchStack() throws -> [Commit] {
        let currentBranch = try self.git.getCheckedOutBranch()
        let upstreamBranch = try self.git.getUpstreamBranch()

        let patches = try git.commits(fromRef: upstreamBranch.remoteBase, toRef: currentBranch)
        return patches.reversed()
    }

    private func iteratorGetPatch(index: Int) throws -> Commit? {
        let patches = try self.iteratorPatchStack()
        guard (index >= 0) && (index < patches.count) else { return nil }
        return patches[index]
    }

    private func getPatch(index: Int) throws -> CommitSummary? {
        let patches = try self.patchStack()
        guard (index >= 0) && (index < patches.count) else { return nil }
        return patches[index]
    }

    private func addIdTo(uuid: UUID, patch: CommitSummary) throws -> CommitSummary {
        let originalBranch = try self.git.getCheckedOutBranch()
        let upstreamBranch = try self.git.getUpstreamBranch()
        let commonAncestorRef = try self.git.mergeBase(refA: patch.sha, refB: upstreamBranch.remoteBase)
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
        try self.git.cherryPickCommits(from: patch.sha, to: upstreamBranch.branch)
        try self.git.forceBranch(named: upstreamBranch.branch, to: "HEAD")
        print("- forced branch (\(upstreamBranch.branch)) to point to HEAD")
        try self.git.checkout(ref: originalBranch)
        print("- checked out branch - \(originalBranch)")
        try self.git.deleteBranch(named: "ps/tmp/add_id_rework")
        print("- deleted tmp working branch - ps/tmp/add_id_rework")
        return try self.git.commitSummary(shaOfPatchFinalPrime)
    }

    private func addIdTo(uuid: UUID, patch: Commit) throws -> Commit? {
        let originalBranch = try self.git.getCheckedOutBranch()
        let upstreamBranch = try self.git.getUpstreamBranch()
        let commonAncestorRef = try self.git.mergeBase(refA: patch.hash, refB: upstreamBranch.remoteBase)
        try self.git.createAndCheckout(branch: "ps/tmp/add_id_rework", startingFrom: commonAncestorRef)
        try self.git.cherryPickCommits(from: commonAncestorRef, to: patch.hash)
        let shaOfPatchPrime = try self.git.getShaOf(ref: "HEAD")
        print("- got sha of HEAD (a.k.a. patch') - \(shaOfPatchPrime)")
        let originalMessage = try self.git.commitMessageOf(ref: shaOfPatchPrime)
        print("- got commit message from \(shaOfPatchPrime) (a.k.a. patch')")
        try self.git.commitAmendMessages(messages: [originalMessage, "ps-id: \(uuid.uuidString)"])
        print("- amended patch' wich ps-id: \(uuid.uuidString), it is now patch''")
        let shaOfPatchFinalPrime = try self.git.getShaOf(ref: "HEAD")
        print("- got sha of HEAD (a.k.a. patch'' - \(shaOfPatchFinalPrime)")
        try self.git.cherryPickCommits(from: patch.hash, to: upstreamBranch.branch)
        try self.git.forceBranch(named: upstreamBranch.branch, to: "HEAD")
        print("- forced branch (\(upstreamBranch.branch)) to point to HEAD")
        try self.git.checkout(ref: originalBranch)
        print("- checked out branch - \(originalBranch)")
        try self.git.deleteBranch(named: "ps/tmp/add_id_rework")
        print("- deleted tmp working branch - ps/tmp/add_id_rework")
        return try self.git.commit(shaOfPatchFinalPrime)
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

        let upstreamBranch = try self.git.getUpstreamBranch()
        print("- found upstream branch - \(upstreamBranch.remoteBase)")

        // Do this so that we are always creating PR branches on top of the latest remote baseBranch
        try self.git.fetch(remote: upstreamBranch.remote, branch: upstreamBranch.branch)
        print("- fetched \(upstreamBranch.branch)")

        // create the new request review branch on remote base
        try self.git.createBranch(named: branchName, on: upstreamBranch.remoteBase)
        print("- created branch (\(branchName)) on (\(upstreamBranch.remoteBase))")

        // checkout the new branch
        try self.git.checkout(ref: branchName)
        print("- checked out \(branchName)")

        do {
            print("- cherry picking commit - \(commitRef)")
            // cherry pick selected commit sha into branch
            try self.git.cherryPick(ref: commitRef)
            let branchSha = try self.git.getRevParse(ref: branchName)
            print("- successfully cherry picked commit - \(commitRef) to \(branchSha)")
        } catch GitShell.Error.gitCherryPickFailure {
            print("Looks like you are trying to request review of a patch that conflicts with \(upstreamBranch.branch). It could be that it is dependent on another patch that is NOT currently in \(upstreamBranch.branch) or just be conflicting with recent changes to \(upstreamBranch.branch).  Dependent patches MUST be in \(upstreamBranch.branch) before requesting review of patches that depend on them.\n")

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

    private func createOrUpdateRequestReviewBranch(named branchName: String, fromCommit fromCommitRef: String, toCommit toCommitRef: String, fallbackBranchName: String) throws {

        let upstreamBranch = try self.git.getUpstreamBranch()
        print("- found upstream branch - \(upstreamBranch.remoteBase)")

        // Do this so that we are always creating PR branches on top of the latest remote baseBranch
        try self.git.fetch(remote: upstreamBranch.remote, branch: upstreamBranch.branch)
        print("- fetched \(upstreamBranch.branch)")

        // create the new request review branch on remote base
        try self.git.createBranch(named: branchName, on: upstreamBranch.remoteBase)
        print("- created branch (\(branchName)) on (\(upstreamBranch.remoteBase))")

        // checkout the new branch
        try self.git.checkout(ref: branchName)
        print("- checked out \(branchName)")

        do {
            print("- cherry picking commit - from: \(fromCommitRef) to: \(toCommitRef)")
            // cherry pick selected commit sha into branch
            try self.git.cherryPickCommits(from: fromCommitRef, to: toCommitRef)
            let branchSha = try self.git.getRevParse(ref: branchName)
            print("- successfully cherry picked commit - from: \(fromCommitRef) to: \(toCommitRef) to \(branchSha)")
        } catch GitShell.Error.gitCherryPickFailure {
            print("Looks like you are trying to request review of a patch that conflicts with \(upstreamBranch.branch). It could be that it is dependent on another patch that is NOT currently in \(upstreamBranch.branch) or just be conflicting with recent changes to \(upstreamBranch.branch).  Dependent patches MUST be in \(upstreamBranch.branch) before requesting review of patches that depend on them.\n")

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
              rebase         Interactive rebase the stack of patches
              rr <i>         Request review of the patch or update existing request to review
              pub <i>        Publish a patch into upstream's stack base (e.g. origin/main)
              --version      Output the version of information for reference & bug reporting
              --help, -h     Show help information

            git-ps ls result structure:
              [patch-index] [review status] [commit short sha] [commit summary]
              "0  rr  788032 Update README with deployment instructions"

            git-ps ls Review Status:
                    Has NOT requested a review (AKA Empty)
              rr    Requested a review and it's unchanged since requesting
              rr+   Requested a review and it has changed since requesting
              p     Commit has been published to upstream's stack base (e.g. origin/main)
            """
        print(text)
    }
}

func showSubCommandHelpText() -> String {
    return """
        usage: git-ps show <patch-index>

        Show the patch diff and details.

    """
}

func requestReviewSubCommandHelpText() -> String {
    return """
        usage: git-ps rr <patch-index> [-n <branch>]

        Request review of the patch or update existing request to review.

        Note: Upon initial request for review of a patch without the
        `-n <branch>` option will result an a branch name being generated
        for the review. Alternatively you can specify a branch using the
        `-n <branch>` option. This is useful when working on teams that have
        explicit branch naming conventions.

    """
}

func publishSubCommandHelpText() -> String {
    return """
        usage: git-ps pub <patch-index> [-f] [-k] [-n <branch>]

        Publish a patch into upstream's stack base (e.g. origin/main)

                  `-f` - force publish, even if a request for review hasn't happened
                  `-k` - keep remote branch around, useful when CI systems have problems
                         with branches being deleted
         `-n <branch>` - explictly specify the branch name that was used for review,
                         useful when dealing with explicit branch naming conventions
    
    """
}

extension String {
  func replaceCharactersFromSet(characterSet: CharacterSet, replacementString: String = "") -> String {
    return self.components(separatedBy: characterSet).joined(separator: replacementString)
  }
}
