import Foundation

public final class GitPatchStack {
		private let arguments: [String]

		public init(arguments: [String] = CommandLine.arguments) { 
				self.arguments = arguments
		}

		public func run() throws {
            print("Hello world")

            let git = try! GitShell(bash: Bash())
            let patches = try! git.patchStack()
            patches.forEach { (patch) in
                print(patch)
            }

//            print(try! Bash().which("git"))
//
//            let outputPipe = Pipe()
//            let errorPipe = Pipe()
//            let task = Process()
//            task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
//            task.arguments = ["--version"]
//            task.standardOutput = outputPipe
//            task.standardError = errorPipe
//
//            // run command
//
//            try! task.run()
//
//            // once complete
//
//            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
//            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
//
//            let output = String(data: outputData, encoding: .utf8)
//            let error = String(data: errorData, encoding: .utf8)

//            let result = run("/usr/bin/git", arguments: ["--version"])

//
//            print("DREW: output:")
//            print(output)
//            print("DREW: error:")
//            print(error)
		}
}
