import Foundation

public func run(_ fileURLWithPath: String, arguments: [String], environment: [String: String]? = nil) throws -> RunResult {
    let outputPipe = Pipe()
    var outputData = Data()

    let errorPipe = Pipe()
    var errorData = Data()

    let task = Process()
    task.executableURL = URL(fileURLWithPath: fileURLWithPath)
    task.arguments = arguments
    task.environment = environment
    task.standardOutput = outputPipe
    task.standardError = errorPipe

    outputPipe.fileHandleForReading.readabilityHandler = { handler in
        outputData.append(handler.availableData)
    }
    errorPipe.fileHandleForReading.readabilityHandler = { handler in
        errorData.append(handler.availableData)
    }

    // Not sure what scenarios this actually throws an error. Could be worth thinking about though
    try task.run()
    task.waitUntilExit()

    let result = RunResult(
        standardOutput: String(data: outputData, encoding: .utf8),
        standardError: String(data: errorData, encoding: .utf8),
        terminationStatus: task.terminationStatus
    )
    return result
}

public func replaceProcess(_ path: String, command: String, arguments: [String]) {
    let args = [command] + arguments

    // Array of UnsafeMutablePointer<Int8>
    let cargs = args.map { strdup($0) } + [nil]

    execv(path, cargs)

    fatalError("Failed to execv")
}
