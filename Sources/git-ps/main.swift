import GitPatchStackCore

let gitPatchStack = GitPatchStack()

do {
    try gitPatchStack.run()
} catch {
    print("Whoops! An error occurred: \(error)")
}
