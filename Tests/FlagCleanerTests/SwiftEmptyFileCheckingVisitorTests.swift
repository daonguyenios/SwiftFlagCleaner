import Testing
import SwiftParser
@testable import FlagCleaner

private func emptyFileCheckingVisitor(from source: String) -> Bool {
    let syntaxTree = Parser.parse(source: source)
    let checkingVisitor = SwiftEmptyFileCheckingVisitor(viewMode: .all)
    _ = checkingVisitor.visit(syntaxTree)

    return checkingVisitor.isEmptyFile
}

@Test func fullyEmpty() async throws {
    let source =
"""
"""

    #expect(emptyFileCheckingVisitor(from: source))
}

@Test func containComments() async throws {
    let source =
"""
// Comment
/*
  Comment
*/
/// Comment
"""

    #expect(emptyFileCheckingVisitor(from: source))
}

@Test func containImports() async throws {
    let source =
"""
import UIKit
import ABC
"""

    #expect(emptyFileCheckingVisitor(from: source))
}
