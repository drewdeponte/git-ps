import GitPatchStackCore

let gitPatchStack = try! GitPatchStack()

do {
    try gitPatchStack.run()
} catch {
    print("Whoops! An error occurred: \(error)")
}
