import Foundation
import SwiftSyntax
import SwiftParser

/// A class that cleans Swift feature flags from source files
public class SwiftCleaner {

    /// A FileManager for working on I/O
    private let fileManager: any FileManagerProtocol

    /// Whether to print verbose output
    private let verbose: Bool
    
    /// Files that had no changes during processing
    public var unchangedFiles: [String] = []
    
    /// Initialize a Swift flag cleaner
    /// - Parameters:
    ///   - fileManager: FileManagerProtocol for working on I/O
    ///   - verbose: Whether to print verbose output
    public init(fileManager: any FileManagerProtocol, verbose: Bool = false) {
        self.fileManager = fileManager
        self.verbose = verbose
    }
    
    /// Process a Swift file to clean a specific flag
    /// - Parameters:
    ///   - filePath: Path to the Swift file
    ///   - flag: Flag name to clean
    /// - Returns: Boolean indicating whether changes were made
    /// - Throws: Error if the file can't be processed
    @discardableResult
    public func processFile(at filePath: String, flag: String) throws -> Bool {
        guard fileManager.fileExists(atPath: filePath) else {
            throw NSError(
                domain: "SwiftCleaner",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "File not found: \(filePath)"
                ]
            )
        }
        
        if verbose {
            print("🔄 Processing Swift file: \(filePath)".lightBlue)
        }
        
        do {
            let fileContent = try fileManager.read(contentsOf: .init(filePath: filePath), encoding: .utf8)
            let parser = Parser.parse(source: fileContent)
            let cleaner = SwiftCleanerRewriter(flag: flag)
            let cleanedSource = cleaner.rewrite(parser.root)

            if cleaner.isEdited {
                let cleanedParserSource = Parser.parse(source: cleanedSource.description)
                let checkingVisitor = SwiftEmptyFileCheckingVisitor(viewMode: .all)
                checkingVisitor.walk(cleanedParserSource)

                if checkingVisitor.isEmptyFile {
                    try fileManager.removeItem(atPath: filePath)

                    if verbose {
                        print("File is empty after cleaning, removed: \(filePath)".lightGreen)
                    }
                }
                else {
                    try fileManager.write(
                        cleanedSource.description,
                        to: .init(filePath: filePath),
                        atomically: true,
                        encoding: .utf8
                    )

                    if verbose {
                        print("✅ Successfully cleaned flag in file: \(filePath)".green)
                    }
                }
                
                return true
            } else {
                if verbose {
                    print("⚠️ No changes made to file: \(filePath)".yellow)
                }
                
                // Add to the collection of unchanged files
                unchangedFiles.append(filePath)
                return false
            }
        } catch {
            if verbose {
                print("❌ Error processing file \(filePath): \(error.localizedDescription)".lightRed)
            }
            throw error
        }
    }
    
    /// Process multiple Swift files to clean a specific flag
    /// - Parameters:
    ///   - filePaths: Array of file paths to process
    ///   - flag: Flag name to clean
    /// - Returns: Dictionary mapping file paths to success/failure
    public func processFiles(at filePaths: [String], flag: String) -> [String: Bool] {
        var results = [String: Bool]()
        
        for filePath in filePaths {
            do {
                let success = try processFile(at: filePath, flag: flag)
                results[filePath] = success
            } catch {
                if verbose {
                    print("Error processing \(filePath): \(error.localizedDescription)")
                }
                results[filePath] = false
            }
        }
        
        return results
    }
}
