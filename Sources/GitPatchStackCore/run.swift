import Foundation

public func run(_ fileURLWithPath: String, arguments: [String]) throws -> RunResult {
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    let task = Process()
    task.executableURL = URL(fileURLWithPath: fileURLWithPath)
    task.arguments = arguments
    task.standardOutput = outputPipe
    task.standardError = errorPipe

    // Not sure what scenarios this actually throws an error. Could be worth thinking about though
    try task.run()
    task.waitUntilExit()

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

    let result = RunResult(standardOutput: String(data: outputData, encoding: .utf8), standardError: String(data: errorData, encoding: .utf8), terminationStatus: task.terminationStatus)
    return result
}

public func replaceProcess(_ path: String, command: String, arguments: [String]) {
    let args = [command] + arguments

    // Array of UnsafeMutablePointer<Int8>
    let cargs = args.map { strdup($0) } + [nil]

    execv(path, cargs)

    fatalError("Failed to execv")
}
