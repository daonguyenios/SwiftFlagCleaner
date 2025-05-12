import XCTest
import Foundation
@testable import SwiftFlagCleanerKit

final class SwiftCleanerTests: XCTestCase {
    // Mock FileManagerProtocol for testing file operations
    class MockFileManager: FileManagerProtocol {
        var currentDirectoryPath: String = "/mock/directory"
        var fileExistsOverride: ((String) -> Bool)?
        var fileContents: [String: String] = [:]
        var removedPaths: [String] = []
        var writtenContents: [String: String] = [:]
        var errorOnRead: Bool = false
        var errorOnWrite: Bool = false
        
        func fileExists(atPath path: String) -> Bool {
            return fileExistsOverride?(path) ?? fileContents.keys.contains(path)
        }
        
        func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
            return fileExists(atPath: path)
        }
        
        func removeItem(atPath path: String) throws {
            if !fileExists(atPath: path) {
                throw NSError(
                    domain: "MockFileManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "File does not exist: \(path)"]
                )
            }
            removedPaths.append(path)
            fileContents.removeValue(forKey: path)
        }
        
        func write(_ content: any StringProtocol, to url: URL, atomically useAuxiliaryFile: Bool, encoding enc: String.Encoding) throws {
            if errorOnWrite {
                throw NSError(
                    domain: "MockFileManager",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Simulated write error"]
                )
            }
            let path = url.path
            writtenContents[path] = content as? String
            fileContents[path] = content as? String
        }
        
        func read(contentsOf url: URL, encoding enc: String.Encoding) throws -> String {
            if errorOnRead {
                throw NSError(
                    domain: "MockFileManager",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Simulated read error"]
                )
            }
            
            let path = url.path
            guard let content = fileContents[path] else {
                throw NSError(
                    domain: "MockFileManager",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "File not found in mock: \(path)"]
                )
            }
            return content
        }
        
        // Helper methods for test setup
        func mockFileContent(at path: String, content: String) {
            fileContents[path] = content
        }
        
        func wasFileRemoved(at path: String) -> Bool {
            return removedPaths.contains(path)
        }
        
        func getWrittenContent(at path: String) -> String? {
            return writtenContents[path]
        }
    }
    
    // Test cases
    func testProcessFileWithSimpleFlag() throws {
        // Setup
        let mockFileManager = MockFileManager()
        let filePath = "/test/path/file.swift"
        
        // Prepare test content with a simple feature flag
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
        
        mockFileManager.mockFileContent(at: filePath, content: sourceCode)
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager, verbose: true)
        let result = try cleaner.processFile(at: filePath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.getWrittenContent(at: filePath), expectedCode)
        XCTAssertTrue(cleaner.unchangedFiles.isEmpty)
    }
    
    func testProcessFileWithIfElseFlag() throws {
        // Setup
        let mockFileManager = MockFileManager()
        let filePath = "/test/path/file.swift"
        
        // Prepare test content with if-else feature flag
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
        
        mockFileManager.mockFileContent(at: filePath, content: sourceCode)
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager)
        let result = try cleaner.processFile(at: filePath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.getWrittenContent(at: filePath), expectedCode)
    }
    
    func testProcessFileWithNestedFlags() throws {
        // Setup
        let mockFileManager = MockFileManager()
        let filePath = "/test/path/file.swift"
        
        // Prepare test content with nested flags
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
        
        mockFileManager.mockFileContent(at: filePath, content: sourceCode)
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager)
        let result = try cleaner.processFile(at: filePath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.getWrittenContent(at: filePath), expectedCode)
    }
    
    func testProcessFileWithUnrelatedFlag() throws {
        // Setup
        let mockFileManager = MockFileManager()
        let filePath = "/test/path/file.swift"
        
        // Prepare test content with an unrelated flag
        let sourceCode = """
        import Foundation
        
        #if UNRELATED_FLAG
        let unrelatedFeature = true
        #endif
        
        class MyClass {}
        """
        
        mockFileManager.mockFileContent(at: filePath, content: sourceCode)
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager)
        let result = try cleaner.processFile(at: filePath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertFalse(result)
        XCTAssertNil(mockFileManager.getWrittenContent(at: filePath))
        XCTAssertEqual(cleaner.unchangedFiles.count, 1)
        XCTAssertEqual(cleaner.unchangedFiles.first, filePath)
    }
    
    func testProcessFileWithMultipleFlags() throws {
        // Setup
        let mockFileManager = MockFileManager()
        let filePath = "/test/path/file.swift"
        
        // Prepare test content with multiple instances of the same flag
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
        
        mockFileManager.mockFileContent(at: filePath, content: sourceCode)
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager)
        let result = try cleaner.processFile(at: filePath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.getWrittenContent(at: filePath), expectedCode)
    }
    
    func testProcessFileWithEmptyResult() throws {
        // Setup
        let mockFileManager = MockFileManager()
        let filePath = "/test/path/file.swift"
        
        // Prepare test content that will be completely empty after processing
        let sourceCode = """
        #if FEATURE_FLAG
        // This file will be empty after processing
        #endif
        """
        
        mockFileManager.mockFileContent(at: filePath, content: sourceCode)
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager)
        let result = try cleaner.processFile(at: filePath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertTrue(mockFileManager.wasFileRemoved(at: filePath))
        XCTAssertNil(mockFileManager.getWrittenContent(at: filePath))
    }
    
    func testFileNotFound() throws {
        // Setup
        let mockFileManager = MockFileManager()
        let nonExistentPath = "/test/path/nonexistent.swift"
        
        // Execute and verify
        let cleaner = SwiftCleaner(fileManager: mockFileManager)
        XCTAssertThrowsError(try cleaner.processFile(at: nonExistentPath, flag: "FEATURE_FLAG")) { error in
            guard let nsError = error as NSError? else {
                XCTFail("Expected NSError")
                return
            }
            XCTAssertEqual(nsError.domain, "SwiftCleaner")
            XCTAssertEqual(nsError.code, 1)
            XCTAssertTrue(nsError.localizedDescription.contains("File not found"))
        }
    }
    
    func testReadFileError() throws {
        // Setup
        let mockFileManager = MockFileManager()
        let filePath = "/test/path/file.swift"
        mockFileManager.mockFileContent(at: filePath, content: "// Test content")
        mockFileManager.errorOnRead = true
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager)
        XCTAssertThrowsError(try cleaner.processFile(at: filePath, flag: "FEATURE_FLAG"))
    }
    
    func testWriteFileError() throws {
        // Setup
        let mockFileManager = MockFileManager()
        let filePath = "/test/path/file.swift"
        
        // Prepare test content with a flag that will trigger a write
        let sourceCode = """
        import Foundation
        
        #if FEATURE_FLAG
        let enabledFeature = true
        #endif
        """
        
        mockFileManager.mockFileContent(at: filePath, content: sourceCode)
        mockFileManager.errorOnWrite = true
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager)
        XCTAssertThrowsError(try cleaner.processFile(at: filePath, flag: "FEATURE_FLAG"))
    }
    
    func testProcessFilesMultipleFiles() throws {
        // Setup
        let mockFileManager = MockFileManager()
        
        let filePath1 = "/test/path/file1.swift"
        let filePath2 = "/test/path/file2.swift"
        let filePath3 = "/test/path/file3.swift"
        
        // Prepare test content for multiple files
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
        
        mockFileManager.mockFileContent(at: filePath1, content: sourceCode1)
        mockFileManager.mockFileContent(at: filePath2, content: sourceCode2)
        mockFileManager.mockFileContent(at: filePath3, content: sourceCode3)
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager)
        let results = cleaner.processFiles(at: [filePath1, filePath2, filePath3], flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[filePath1] ?? false)
        XCTAssertFalse(results[filePath2] ?? true)
        XCTAssertTrue(results[filePath3] ?? false)
        XCTAssertEqual(cleaner.unchangedFiles.count, 1)
        XCTAssertEqual(cleaner.unchangedFiles[0], filePath2)
    }
    
    func testProcessFilesWithError() throws {
        // Setup
        let mockFileManager = MockFileManager()
        
        let filePath1 = "/test/path/file1.swift"
        let filePath2 = "/test/path/file2.swift" // Will cause an error
        let filePath3 = "/test/path/file3.swift"
        
        // Prepare test content
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
        
        mockFileManager.mockFileContent(at: filePath1, content: sourceCode1)
        mockFileManager.mockFileContent(at: filePath3, content: sourceCode3)
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager, verbose: true)
        let results = cleaner.processFiles(at: [filePath1, filePath2, filePath3], flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[filePath1] ?? false)
        XCTAssertFalse(results[filePath2] ?? true) // Should be false due to error
        XCTAssertTrue(results[filePath3] ?? false)
    }
    
    func testNegatedFlags() throws {
        // Setup
        let mockFileManager = MockFileManager()
        let filePath = "/test/path/file.swift"
        
        // Prepare test content with a negated flag
        let sourceCode = """
        import Foundation
        
        #if !FEATURE_FLAG
        let disabledFeature = true
        #else
        let enabledFeature = true
        #endif
        """
        
        let expectedCode = """
        import Foundation
        
        let enabledFeature = true
        """
        
        mockFileManager.mockFileContent(at: filePath, content: sourceCode)
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager)
        let result = try cleaner.processFile(at: filePath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.getWrittenContent(at: filePath), expectedCode)
    }
    
    func testComplexNestedFlags() throws {
        // Setup
        let mockFileManager = MockFileManager()
        let filePath = "/test/path/file.swift"
        
        // Prepare test content with complex nested flags
        let sourceCode = """
        import Foundation
        
        #if DEBUG
        #if FEATURE_FLAG
            let debugFeatureEnabled = true
        #else
            let debugFeatureDisabled = true
        #endif
        #else
        #if FEATURE_FLAG
            let releaseFeatureEnabled = true
        #else
            let releaseFeatureDisabled = true
        #endif
        #endif
        """
        
        let expectedCode = """
        import Foundation
        
        #if DEBUG
            let debugFeatureEnabled = true
        #else
            let releaseFeatureEnabled = true
        #endif
        """
        
        mockFileManager.mockFileContent(at: filePath, content: sourceCode)
        
        // Execute
        let cleaner = SwiftCleaner(fileManager: mockFileManager)
        let result = try cleaner.processFile(at: filePath, flag: "FEATURE_FLAG")
        
        // Verify
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.getWrittenContent(at: filePath), expectedCode)
    }
}


import Foundation

#if DEBUG
  #if FEATURE_FLAG
    let debugFeatureEnabled = true
  #else
    let debugFeatureDisabled = true
  #endif
#else
  #if FEATURE_FLAG
    let releaseFeatureEnabled = true
  #else
    let releaseFeatureDisabled = true
  #endif
#endif
