import Foundation

/// A class that cleans Objective-C flags from source files
public class ObjcCleaner {

    /// A FileManager for working on I/O
    private let fileManager: any FileManagerProtocol

    /// Whether to print verbose output
    private let verbose: Bool
    
    /// Files that had no changes during processing
    public private(set) var unchangedFiles: [String] = []
    
    /// Initialize an Objective-C flag cleaner
    /// - Parameters:
    ///   - fileManager: FileManagerProtocol for working on I/O
    ///   - verbose: Whether to print verbose output
    public init(
        fileManager: any FileManagerProtocol,
        verbose: Bool = false
    ) {
        self.fileManager = fileManager
        self.verbose = verbose
    }
    
    /// Process an Objective-C file to clean a specific flag
    /// - Parameters:
    ///   - filePath: Path to the Objective-C file
    ///   - flag: Flag name to clean
    /// - Returns: Boolean indicating success
    /// - Throws: Error if the file can't be processed
    @discardableResult
    public func processFile(at filePath: String, flag: String) throws -> Bool {
        guard fileManager.fileExists(atPath: filePath) else {
            throw NSError(
                domain: "ObjcCleaner",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "File not found: \(filePath)"
                ]
            )
        }
        
        if verbose {
            print("🔄 Processing Objective-C file: \(filePath)")
        }
        
        // Read the file content before processing to compare later
        let originalContent: String
        do {
            originalContent = try fileManager.read(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8)
        } catch {
            throw error
        }
        
        // Create environment variables for the commands
        var environment = ProcessInfo.processInfo.environment
        environment["FLAG"] = flag
        
        // Process #if directives
        let ifPerlCommand = """
        perl -0777 -ni -e '
          (s|(#if \\Q$ENV{FLAG}\\E.*\\n)([\\s\\S]*?)(#elif.*\\n[\\s\\S]*?)?(#else.*\\n[\\s\\S]*?)?(#endif.*\\n?)|$2|g);
          print $_;
        ' "\(filePath)"
        """
        
        try executePerlCommand(ifPerlCommand, environment: environment, description: "#if")
        
        // Process #ifdef directives
        let ifdefPerlCommand = """
        perl -0777 -ni -e '
          (s|(#ifdef \\Q$ENV{FLAG}\\E.*\\n)([\\s\\S]*?)(#elif.*\\n[\\s\\S]*?)?(#else.*\\n[\\s\\S]*?)?(#endif.*\\n?)|$2|g);
          print $_;
        ' "\(filePath)"
        """
        
        try executePerlCommand(ifdefPerlCommand, environment: environment, description: "#ifdef")
        
        // Read the file content after processing to check if it changed
        let modifiedContent = try fileManager.read(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8)
        let hasChanges = originalContent != modifiedContent
        
        if hasChanges {
            if verbose {
                print("✅ Successfully processed file: \(filePath)")
            }
            return true
        } else {
            if verbose {
                print("⚠️ No changes made to file: \(filePath)")
            }
            
            // Add to the collection of unchanged files
            unchangedFiles.append(filePath)
            return false
        }
    }
    
    /// Execute a Perl command to process a file
    /// - Parameters:
    ///   - command: The Perl command to execute
    ///   - environment: Environment variables for the command
    ///   - description: Description of what the command does (for error messages)
    /// - Throws: Error if the command fails
    private func executePerlCommand(_ command: String, environment: [String: String], description: String) throws {
        if verbose {
            print("Executing \(description) Perl command: \(command)")
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]
        task.environment = environment
        
        // Capture output and errors
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let status = task.terminationStatus
            
            if status != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                
                if verbose {
                    print("❌ Error processing \(description) directive: \(errorMessage)")
                }
                
                throw NSError(
                    domain: "ObjcCleaner",
                    code: Int(status),
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to process \(description) directive: \(errorMessage)"
                    ]
                )
            }
        } catch {
            if verbose {
                print("Failed to execute \(description) command: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    /// Process multiple Objective-C files to clean a specific flag
    /// - Parameters:
    ///   - filePaths: Array of file paths to process
    ///   - flag: Flag name to clean
    /// - Returns: Dictionary mapping file paths to success/failure
    /// - Throws: Error if any file can't be processed
    public func processFiles(at filePaths: [String], flag: String) -> [String: Bool] {
        var results = [String: Bool]()
        
        for filePath in filePaths {
            do {
                let success = try processFile(at: filePath, flag: flag)
                results[filePath] = success
            } catch {
                if verbose {
                    print("❌ Error processing \(filePath): \(error.localizedDescription)")
                }
                results[filePath] = false
            }
        }
        
        return results
    }
}
