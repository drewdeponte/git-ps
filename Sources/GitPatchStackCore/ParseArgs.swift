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

    let parser: Parser<ArraySlice<Substring>, Command> = zip(.first(.everything()),.oneOf(
        helpCommand,
        versionCommand,
        listSubcommand,
        showSubcommand,
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

func parseRequestReviewSubcommand(_ args: ArraySlice<Substring>) -> (patchIndex: Int, options: [RequestReviewOption])? {

    let requestReviewHelpOption: Parser<ArraySlice<Substring>, RequestReviewOption> = .oneOf(.first("-h"), .first("--help")).map { .help }

    let requestReviewBranchOption: Parser<ArraySlice<Substring>, RequestReviewOption> = zip(
        .first("-n"),
        .first(.everything())
    ).map { _, branch in .branch(name: String(branch)) }

    let requestReviewOptions: Parser<ArraySlice<Substring>, [RequestReviewOption]> = .oneOf(
        requestReviewHelpOption,
        requestReviewBranchOption
    ).zeroOrMore()

    let requestReviewSubcommand: Parser<ArraySlice<Substring>, (patchIndex: Int, options: [RequestReviewOption])> = zip(
        requestReviewOptions,
        patchIndex,
        requestReviewOptions
    ).map { opts1, patchIndex, opts2 in (patchIndex: patchIndex, options: opts1 + opts2) }

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
