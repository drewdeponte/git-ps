import Foundation
import FunctionalParserKit

enum Command {
    enum SubCommand {
        enum RequestReviewOption: Equatable {
            case branch(name: String)

            var branchName: String? {
                switch self {
                case .branch(name: let name): return name
                }
            }
        }

        enum PublishOption: Equatable {
            case force
            case keep
            case branch(name: String)

            var branchName: String? {
                switch self {
                case .branch(name: let name): return name
                case .force: return nil
                case .keep: return nil
                }
            }
        }

        case list
        case show(patchIndex: Int)
        case pull
        case rebase
        case requestReview(patchIndex: Int, options: [RequestReviewOption])
        case publish(patchIndex: Int, options: [PublishOption])
    }

    case help
    case version
    case subcommand(SubCommand)
}

func parse(_ arguments: [String]) -> Command? {
    let patchIndex: Parser<ArraySlice<Substring>, Int> = .first(.int())

    let helpCommand: Parser<ArraySlice<Substring>, Command> = .oneOf(
        .first("--help"),
        .first("-h")
    ).map { .help }

    let versionCommand: Parser<ArraySlice<Substring>, Command> = .oneOf(
        .first("--version"),
        .first("-v")
    ).map { .version }

    let listSubcommand: Parser<ArraySlice<Substring>, Command.SubCommand> = .first("ls").map { .list }

    let showSubcommand: Parser<ArraySlice<Substring>, Command.SubCommand> = zip(
        .first("show"),
        patchIndex
    ).map { _, patchIndex in .show(patchIndex: patchIndex) }

    let pullSubcommand: Parser<ArraySlice<Substring>, Command.SubCommand> = .first("pull").map { .pull }

    let rebaseSubcommand: Parser<ArraySlice<Substring>, Command.SubCommand> = .first("rebase").map { .rebase }

    let requestReviewBranchOption: Parser<ArraySlice<Substring>, Command.SubCommand.RequestReviewOption> = zip(
        .first("-n"),
        .first(.everything())
    ).map { _, branch in .branch(name: String(branch)) }

    let requestReviewOptions: Parser<ArraySlice<Substring>, Command.SubCommand.RequestReviewOption> = .oneOf(
        requestReviewBranchOption
    )

    let requestReviewSubcommand: Parser<ArraySlice<Substring>, Command.SubCommand> = zip(
        .first("rr"),
        requestReviewOptions.zeroOrMore(),
        patchIndex,
        requestReviewOptions.zeroOrMore()
    ).map { _, opts1, patchIndex, opts2 in .requestReview(patchIndex: patchIndex, options: opts1 + opts2) }

    let publishForceOption: Parser<ArraySlice<Substring>, Command.SubCommand.PublishOption> = .first("-f").map { .force }
    let publishKeepOption: Parser<ArraySlice<Substring>, Command.SubCommand.PublishOption> = .first("-k").map { .keep }
    let publishBranchOption: Parser<ArraySlice<Substring>, Command.SubCommand.PublishOption> = zip(
        .first("-n"),
        .first(.everything())
    ).map { _, branch in .branch(name: String(branch)) }

    let publishOptions: Parser<ArraySlice<Substring>, Command.SubCommand.PublishOption> = .oneOf(
        publishForceOption,
        publishKeepOption,
        publishBranchOption
    )

    let publishSubcommand: Parser<ArraySlice<Substring>, Command.SubCommand> = zip(
        .first("pub"),
        publishOptions.zeroOrMore(),
        patchIndex,
        publishOptions.zeroOrMore()
    ).map { _, opts1, patchIndex, opts2 in .publish(patchIndex: patchIndex, options: opts1 + opts2) }

    let subcommandCommand: Parser<ArraySlice<Substring>, Command> = .oneOf(
        listSubcommand,
        showSubcommand,
        pullSubcommand,
        rebaseSubcommand,
        requestReviewSubcommand,
        publishSubcommand
    ).map { .subcommand($0) }

    let command: Parser<ArraySlice<Substring>, Command> = .oneOf(
        subcommandCommand,
        helpCommand,
        versionCommand
    )

    let argsParser: Parser<ArraySlice<Substring>, Command> = zip(
        .first(.everything()), // consume command name
        command
    ).map { _, cmd in cmd }

    var args: ArraySlice<Substring> = arguments.map { $0[...] }[...]
    return argsParser.run(&args)
}
