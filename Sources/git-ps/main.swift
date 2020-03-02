import GitPatchStackCore

let gitPatchStack = try! GitPatchStack()

do {
    try gitPatchStack.run()
} catch GitPatchStack.Error.invalidArgumentCount {
    print("Default commands are: \n\n git-ps (ls, show <patch-index>, pull, rebase, rr <patch-index>, pub <patch-index>, --version).")
} catch {
    print("Whoops! An error occurred: \(error)")
}

