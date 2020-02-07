import XCTest

import git_ps_Tests

var tests = [XCTestCaseEntry]()
tests += git_ps_Tests.allTests()
XCTMain(tests)
