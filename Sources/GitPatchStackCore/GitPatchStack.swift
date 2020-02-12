import Foundation

public final class GitPatchStack {
		private let arguments: [String]

        private let remote: String
        private let baseBranch: String
        private var remoteBase: String {
            return "\(self.remote)/\(self.baseBranch)"
        }

		public init(arguments: [String] = CommandLine.arguments, remote: String = "origin", baseBranch: String = "master") { 
				self.arguments = arguments
            self.remote = remote
            self.baseBranch = baseBranch
		}

		public func run() throws {
            print("Hello world")

            let git = try! GitShell(bash: Bash())
            let patches = try! git.commits(from: self.remoteBase, to: self.baseBranch)
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
