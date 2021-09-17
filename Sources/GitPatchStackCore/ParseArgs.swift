import Foundation
import FunctionalParserKit

let patchIndex: Parser<ArraySlice<Substring>, Int> = .first(.int())

enum Command {
    case help
    case version
    case list
    case show(args: ArraySlice<Substring>)
    case pull
    case rebase
    case requestReview(args: ArraySlice<Substring>)
    case publish(args: ArraySlice<Substring>)
    case checkout(args: ArraySlice<Substring>)
    case patchHashContent(args: ArraySlice<Substring>)
}

func parseCommand(_ arguments: [String]) -> Command? {
    let helpCommand: Parser<ArraySlice<Substring>, Command> = .oneOf(
        .first("--help"),
        .first("-h")
    ).map { .help }

    let versionCommand: Parser<ArraySlice<Substring>, Command> = .oneOf(
        .first("--version"),
        .first("-v")
    ).map { .version }

    let listSubcommand: Parser<ArraySlice<Substring>, Command> = .first("ls").map { .list }
    let pullSubcommand: Parser<ArraySlice<Substring>, Command> = .first("pull").map { .pull }
    let rebaseSubcommand: Parser<ArraySlice<Substring>, Command> = .first("rebase").map { .rebase }

    let showSubcommand: Parser<ArraySlice<Substring>, Command> = zip(.first("show"), .everything()).map { _, subCmdArgs in .show(args: subCmdArgs) }
    let requestReviewSubcommand: Parser<ArraySlice<Substring>, Command> = zip(.first("rr"), .everything()).map { _, subCmdArgs in .requestReview(args: subCmdArgs) }
    let publishSubcommand: Parser<ArraySlice<Substring>, Command> = zip(.first("pub"), .everything()).map { _, subCmdArgs in .publish(args: subCmdArgs) }
    let checkoutSubcommand: Parser<ArraySlice<Substring>, Command> = zip(.first("co"), .everything()).map { _, subCmdArgs in .checkout(args: subCmdArgs) }
    let patchHashContentSubcommand: Parser<ArraySlice<Substring>, Command> = zip(.first("patch-hash-content"), .everything()).map { _, subCmdArgs in .patchHashContent(args: subCmdArgs) }

    let parser: Parser<ArraySlice<Substring>, Command> = zip(.first(.everything()),.oneOf(
        helpCommand,
        versionCommand,
        listSubcommand,
        showSubcommand,
        checkoutSubcommand,
        patchHashContentSubcommand,
        pullSubcommand,
        rebaseSubcommand,
        requestReviewSubcommand,
        publishSubcommand
    )).map { _, subCmd in return subCmd }

    var args: ArraySlice<Substring> = arguments.map { $0[...] }[...]
    return parser.run(&args)
}

enum ShowOption: Equatable {
    case help
}

func parseShowSubcommand(_ args: ArraySlice<Substring>) -> (patchIndex: Int, options: [ShowOption])? {
    let showHelpOption: Parser<ArraySlice<Substring>, ShowOption> = .oneOf(.first("-h"), .first("--help")).map { .help }

    let showOptions: Parser<ArraySlice<Substring>, [ShowOption]> = .oneOf(showHelpOption).zeroOrMore()

    let showSubcommand: Parser<ArraySlice<Substring>, (patchIndex: Int, options: [ShowOption])> = zip(
        showOptions,
        patchIndex,
        showOptions
    ).map { opts1, patchIndex, opts2 in (patchIndex: patchIndex, options: opts1 + opts2) }

    var vArgs = args
    return showSubcommand.run(&vArgs)
}

enum CheckoutOption: Equatable {
    case help
}

func parseCheckoutSubcommand(_ args: ArraySlice<Substring>) -> (patchIndex: Int, options: [CheckoutOption])? {
    let checkoutHelpOption: Parser<ArraySlice<Substring>, CheckoutOption> = .oneOf(.first("-h"), .first("--help")).map { .help }

    let checkoutOptions: Parser<ArraySlice<Substring>, [CheckoutOption]> = .oneOf(checkoutHelpOption).zeroOrMore()

    let checkoutSubcommand: Parser<ArraySlice<Substring>, (patchIndex: Int, options: [CheckoutOption])> = zip(checkoutOptions, patchIndex, checkoutOptions).map { opts1, patchIndex, opts2 in (patchIndex: patchIndex, options: opts1 + opts2) }

    var vArgs = args
    return checkoutSubcommand.run(&vArgs)
}

enum PatchHashContentOption: Equatable {
    case help
}

func parsePatchHashContentSubcommand(_ args: ArraySlice<Substring>) -> (patchIndex: Int, options: [PatchHashContentOption])? {
    let patchHashContentHelpOption: Parser<ArraySlice<Substring>, PatchHashContentOption> = .oneOf(.first("-h"), .first("--help")).map { .help }

    let patchHashContentOptions: Parser<ArraySlice<Substring>, [PatchHashContentOption]> = .oneOf(patchHashContentHelpOption).zeroOrMore()

    let patchHashContentSubcommand: Parser<ArraySlice<Substring>, (patchIndex: Int, options: [PatchHashContentOption])> = zip(patchHashContentOptions, patchIndex, patchHashContentOptions).map { opts1, patchIndex, opts2 in (patchIndex: patchIndex, options: opts1 + opts2) }

    var vArgs = args
    return patchHashContentSubcommand.run(&vArgs)
}

enum RequestReviewOption: Equatable {
    case branch(name: String)
    case help

    var branchName: String? {
        switch self {
        case .branch(name: let name): return name
        case .help: return nil
        }
    }
}

public struct PatchIndexRange { // inclusive
    let startIndex: Int
    let endIndex: Int

    var isSingular: Bool {
        return startIndex == endIndex
    }
}

func parseRequestReviewSubcommand(_ args: ArraySlice<Substring>) -> (patchIndexRange: PatchIndexRange, options: [RequestReviewOption])? {

    // git ps rr 5 -n mybranch
    // git ps rr 5
    // git ps rr [--help | -h]

    // git ps rr 2-4
    // git ps rr 2 4
    // git ps rr <patch-start-index> <patch-end-index>

    // stack:
    // 4 - something
    // 3 - orignal something
    // 2 - ....
    // 1 - ....

    // git ps rr 3

    // stack:
    // 5 - something
    // 4 - fix original something
    // 3 - orignal something
    // 2 - ....
    // 1 - ....

    // stack:
    // 6 - something
    // 5 - fix original something
    // 4 - orignal something
    // 3 - prefix orignal somethnig
    // 2 - ....
    // 1 - ....

    // git ps rr 3-6 [-n <branch-name>]

    let requestReviewHelpOption: Parser<ArraySlice<Substring>, RequestReviewOption> = .oneOf(.first("-h"), .first("--help")).map { .help }

    let requestReviewBranchOption: Parser<ArraySlice<Substring>, RequestReviewOption> = zip(
        .first("-n"),
        .first(.everything())
    ).map { _, branch in .branch(name: String(branch)) }

    let requestReviewOptions: Parser<ArraySlice<Substring>, [RequestReviewOption]> = .oneOf(
        requestReviewHelpOption,
        requestReviewBranchOption
    ).zeroOrMore()

    let patchRangeDashSeparated: Parser<ArraySlice<Substring>, PatchIndexRange> = .first(
        zip(.int(), "-", .int()).map { si, _, ei in PatchIndexRange(startIndex: si, endIndex: ei) }
    )

    let patchRangeSpaceSeparated: Parser<ArraySlice<Substring>, PatchIndexRange> = zip(
        patchIndex,patchIndex
    ).map { si, ei in PatchIndexRange(startIndex: si, endIndex: ei) }

    let patchIndexRange: Parser<ArraySlice<Substring>, PatchIndexRange> = .oneOf(
        patchRangeDashSeparated,
        patchRangeSpaceSeparated,
        patchIndex.map { PatchIndexRange(startIndex: $0, endIndex: $0) }
    )

    let requestReviewSubcommand: Parser<ArraySlice<Substring>, (patchIndexRange: PatchIndexRange, options: [RequestReviewOption])> = zip(
        requestReviewOptions,
        patchIndexRange,
        requestReviewOptions
    ).map { opts1, patchIndexRange, opts2 in (patchIndexRange: patchIndexRange, options: opts1 + opts2) }

    var vArgs = args
    return requestReviewSubcommand.run(&vArgs)
}

enum PublishOption: Equatable {
    case force
    case keep
    case branch(name: String)
    case help

    var branchName: String? {
        switch self {
        case .branch(name: let name): return name
        case .force: return nil
        case .keep: return nil
        case .help: return nil
        }
    }
}

func parsePublishSubcommand(_ args: ArraySlice<Substring>) -> (patchIndex: Int, options: [PublishOption])? {
    let publishHelpOption: Parser<ArraySlice<Substring>, PublishOption> = .oneOf(.first("-h"), .first("--help")).map { .help }
    let publishForceOption: Parser<ArraySlice<Substring>, PublishOption> = .first("-f").map { .force }
    let publishKeepOption: Parser<ArraySlice<Substring>, PublishOption> = .first("-k").map { .keep }
    let publishBranchOption: Parser<ArraySlice<Substring>, PublishOption> = zip(
        .first("-n"),
        .first(.everything())
    ).map { _, branch in .branch(name: String(branch)) }

    let publishOptions: Parser<ArraySlice<Substring>, PublishOption> = .oneOf(
        publishHelpOption,
        publishForceOption,
        publishKeepOption,
        publishBranchOption
    )

    let publishSubcommand: Parser<ArraySlice<Substring>, (patchIndex: Int, options: [PublishOption])> = zip(
        publishOptions.zeroOrMore(),
        patchIndex,
        publishOptions.zeroOrMore()
    ).map { opts1, patchIndex, opts2 in (patchIndex: patchIndex, options: opts1 + opts2) }

    var vArgs = args
    return publishSubcommand.run(&vArgs)
}
