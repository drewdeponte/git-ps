import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(git_ps_swiftTests.allTests),
    ]
}
#endif
