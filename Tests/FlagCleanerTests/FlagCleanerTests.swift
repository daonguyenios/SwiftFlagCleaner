import XCTest
import Foundation
import SwiftParser
@testable import FlagCleaner

final class FlagCleanerTests: XCTestCase {
    // Mock FileManager for testing file operations
    class MockFileManager: FileManager {
        var fileExistsOverride: ((String) -> Bool)?
        var contentsMap: [String: String] = [:]
        var removedFiles: [String] = []
        var writtenFiles: [String: String] = [:]
        
        override func fileExists(atPath path: String) -> Bool {
            return fileExistsOverride?(path) ?? super.fileExists(atPath: path)
        }
        
        override func removeItem(atPath path: String) throws {
            removedFiles.append(path)
        }
        
        // Mock file read/write
        func setupMockContent(_ path: String, content: String) {
            contentsMap[path] = content
        }
        
        // Track written files for verification
        func getWrittenContent(_ path: String) -> String? {
            return writtenFiles[path]
        }
    }
    
    // MockFileManager extension to simulate String.init(contentsOf:) and String.write(to:)
    class MockStringExtensions {
        private let fileManager: MockFileManager
        
        init(fileManager: MockFileManager) {
            self.fileManager = fileManager
        }
        
        func readContents(atPath path: String) throws -> String {
            if let content = fileManager.contentsMap[path] {
                return content
            }
            throw NSError(domain: "MockFileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        
        func writeContents(_ string: String, toPath path: String) throws {
            fileManager.writtenFiles[path] = string
        }
    }
    
    // SwiftFlagCleaner subclass that uses our mocks
    class TestableSwiftFlagCleaner: SwiftFlagCleaner {
        let mockFileManager: MockFileManager
        let mockStringExtensions: MockStringExtensions
        
        init(mockFileManager: MockFileManager, verbose: Bool = false) {
            self.mockFileManager = mockFileManager
            self.mockStringExtensions = MockStringExtensions(fileManager: mockFileManager)
            super.init(verbose: verbose)
        }
        
        override func processFile(at filePath: String, flag: String) throws -> Bool {
            guard mockFileManager.fileExists(atPath: filePath) else {
                throw NSError(domain: "SwiftFlagCleaner", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "File not found: \(filePath)"])
            }
            
            do {
                let fileContent = try mockStringExtensions.readContents(atPath: filePath)
                let parser = Parser.parse(source: fileContent)
                let cleaner = SwiftFlagCleanerRewriter(flag: flag)
                let cleanedSource = cleaner.rewrite(parser.root)

                if cleaner.isEdited {
                    let cleanedParserSource = Parser.parse(source: cleanedSource.description)
                    let checkingVisitor = SwiftEmptyFileCheckingVisitor(viewMode: .all)
                    checkingVisitor.walk(cleanedParserSource)

                    if checkingVisitor.isEmptyFile {
                        mockFileManager.removedFiles.append(filePath)
                    } else {
                        try mockStringExtensions.writeContents(cleanedSource.description, toPath: filePath)
                    }
                    
                    return true
                } else {
                    unchangedFiles.append(filePath)
                    return false
                }
            } catch {
                throw error
            }
        }
    }
    
    // Test cases
    func testProcessFileWithSimpleFlag() throws {
        // Setup
        let mockFileManager = MockFileManager()
        mockFileManager.fileExistsOverride = { _ in true }
        
        let sourceCode = """
        import Foundation
        
        #if FEATURE_FLAG
        let enabledFeature = true
        #endif
        
        class MyClass {}
        """
        
        let expectedCode = """
        import Foundation
        
        let enabledFeature = true
        
        class MyClass {}
        """
        
        let testPath = "/test/path/file.swift"
        mockFileManager.setupMockContent(testPath, content: sourceCode)
        
        // Execute
        let cleaner = TestableSwiftFlagCleaner(mockFileManager: mockFileManager, verbose: true)
        let result = try cleaner.processFile(at: testPath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.getWrittenContent(testPath), expectedCode)
        XCTAssertTrue(cleaner.unchangedFiles.isEmpty)
    }
    
    func testProcessFileWithIfElseFlag() throws {
        // Setup
        let mockFileManager = MockFileManager()
        mockFileManager.fileExistsOverride = { _ in true }
        
        let sourceCode = """
        import Foundation
        
        #if FEATURE_FLAG
        let enabledFeature = true
        #else
        let enabledFeature = false
        #endif
        
        class MyClass {}
        """
        
        let expectedCode = """
        import Foundation
        
        let enabledFeature = true
        
        class MyClass {}
        """
        
        let testPath = "/test/path/file.swift"
        mockFileManager.setupMockContent(testPath, content: sourceCode)
        
        // Execute
        let cleaner = TestableSwiftFlagCleaner(mockFileManager: mockFileManager)
        let result = try cleaner.processFile(at: testPath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.getWrittenContent(testPath), expectedCode)
    }
    
    func testProcessFileWithNestedFlags() throws {
        // Setup
        let mockFileManager = MockFileManager()
        mockFileManager.fileExistsOverride = { _ in true }
        
        let sourceCode = """
        import Foundation
        
        #if GLOBAL_FLAG
        class OuterClass {
            #if FEATURE_FLAG
            func enabledFeature() {
                print("This is enabled")
            }
            #else
            func disabledFeature() {
                print("This is disabled")
            }
            #endif
        }
        #endif
        """
        
        let expectedCode = """
        import Foundation
        
        #if GLOBAL_FLAG
        class OuterClass {
            func enabledFeature() {
                print("This is enabled")
            }
        }
        #endif
        """
        
        let testPath = "/test/path/file.swift"
        mockFileManager.setupMockContent(testPath, content: sourceCode)
        
        // Execute
        let cleaner = TestableSwiftFlagCleaner(mockFileManager: mockFileManager)
        let result = try cleaner.processFile(at: testPath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.getWrittenContent(testPath), expectedCode)
    }
    
    func testProcessFileWithUnrelatedFlag() throws {
        // Setup
        let mockFileManager = MockFileManager()
        mockFileManager.fileExistsOverride = { _ in true }
        
        let sourceCode = """
        import Foundation
        
        #if UNRELATED_FLAG
        let unrelatedFeature = true
        #endif
        
        class MyClass {}
        """
        
        let testPath = "/test/path/file.swift"
        mockFileManager.setupMockContent(testPath, content: sourceCode)
        
        // Execute
        let cleaner = TestableSwiftFlagCleaner(mockFileManager: mockFileManager)
        let result = try cleaner.processFile(at: testPath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertFalse(result)
        XCTAssertNil(mockFileManager.getWrittenContent(testPath))
        XCTAssertEqual(cleaner.unchangedFiles.count, 1)
        XCTAssertEqual(cleaner.unchangedFiles.first, testPath)
    }
    
    func testProcessFileWithMultipleFlags() throws {
        // Setup
        let mockFileManager = MockFileManager()
        mockFileManager.fileExistsOverride = { _ in true }
        
        let sourceCode = """
        import Foundation
        
        #if FEATURE_FLAG
        let enabledFeature1 = true
        #endif
        
        class MyClass {}
        
        #if FEATURE_FLAG
        extension MyClass {
            func extraFeature() {}
        }
        #endif
        """
        
        let expectedCode = """
        import Foundation
        
        let enabledFeature1 = true
        
        class MyClass {}
        
        extension MyClass {
            func extraFeature() {}
        }
        """
        
        let testPath = "/test/path/file.swift"
        mockFileManager.setupMockContent(testPath, content: sourceCode)
        
        // Execute
        let cleaner = TestableSwiftFlagCleaner(mockFileManager: mockFileManager)
        let result = try cleaner.processFile(at: testPath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.getWrittenContent(testPath), expectedCode)
    }
    
    func testProcessFileWithEmptyResult() throws {
        // Setup
        let mockFileManager = MockFileManager()
        mockFileManager.fileExistsOverride = { _ in true }
        
        let sourceCode = """
        #if FEATURE_FLAG
        // This file will be empty after processing
        #endif
        """
        
        let testPath = "/test/path/file.swift"
        mockFileManager.setupMockContent(testPath, content: sourceCode)
        
        // Execute
        let cleaner = TestableSwiftFlagCleaner(mockFileManager: mockFileManager)
        let result = try cleaner.processFile(at: testPath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertTrue(mockFileManager.removedFiles.contains(testPath))
        XCTAssertNil(mockFileManager.getWrittenContent(testPath))
    }
    
    func testFileNotFound() throws {
        // Setup
        let mockFileManager = MockFileManager()
        mockFileManager.fileExistsOverride = { _ in false }
        
        let testPath = "/test/path/nonexistent.swift"
        
        // Execute and verify
        let cleaner = TestableSwiftFlagCleaner(mockFileManager: mockFileManager)
        XCTAssertThrowsError(try cleaner.processFile(at: testPath, flag: "FEATURE_FLAG")) { error in
            guard let nsError = error as NSError? else {
                XCTFail("Expected NSError")
                return
            }
            XCTAssertEqual(nsError.domain, "SwiftFlagCleaner")
            XCTAssertEqual(nsError.code, 1)
            XCTAssertTrue(nsError.localizedDescription.contains("File not found"))
        }
    }
    
    func testProcessFilesMultipleFiles() throws {
        // Setup
        let mockFileManager = MockFileManager()
        mockFileManager.fileExistsOverride = { _ in true }
        
        let sourceCode1 = """
        #if FEATURE_FLAG
        let enabledFeature = true
        #endif
        """
        
        let sourceCode2 = """
        #if OTHER_FLAG
        let otherFeature = true
        #endif
        """
        
        let sourceCode3 = """
        #if FEATURE_FLAG
        let anotherFeature = true
        #endif
        """
        
        let testPath1 = "/test/path/file1.swift"
        let testPath2 = "/test/path/file2.swift"
        let testPath3 = "/test/path/file3.swift"
        
        mockFileManager.setupMockContent(testPath1, content: sourceCode1)
        mockFileManager.setupMockContent(testPath2, content: sourceCode2)
        mockFileManager.setupMockContent(testPath3, content: sourceCode3)
        
        // Execute
        let cleaner = TestableSwiftFlagCleaner(mockFileManager: mockFileManager)
        let results = cleaner.processFiles(at: [testPath1, testPath2, testPath3], flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[testPath1] ?? false)
        XCTAssertFalse(results[testPath2] ?? true)
        XCTAssertTrue(results[testPath3] ?? false)
        XCTAssertEqual(cleaner.unchangedFiles.count, 1)
        XCTAssertEqual(cleaner.unchangedFiles.first, testPath2)
    }
    
    func testProcessFilesWithError() throws {
        // Setup
        let mockFileManager = MockFileManager()
        mockFileManager.fileExistsOverride = { path in
            // Make one file "not exist"
            return path != "/test/path/file2.swift"
        }
        
        let sourceCode1 = """
        #if FEATURE_FLAG
        let enabledFeature = true
        #endif
        """
        
        let sourceCode3 = """
        #if FEATURE_FLAG
        let anotherFeature = true
        #endif
        """
        
        let testPath1 = "/test/path/file1.swift"
        let testPath2 = "/test/path/file2.swift"
        let testPath3 = "/test/path/file3.swift"
        
        mockFileManager.setupMockContent(testPath1, content: sourceCode1)
        mockFileManager.setupMockContent(testPath3, content: sourceCode3)
        
        // Execute
        let cleaner = TestableSwiftFlagCleaner(mockFileManager: mockFileManager, verbose: true)
        let results = cleaner.processFiles(at: [testPath1, testPath2, testPath3], flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[testPath1] ?? false)
        XCTAssertFalse(results[testPath2] ?? true)
        XCTAssertTrue(results[testPath3] ?? false)
    }
}
