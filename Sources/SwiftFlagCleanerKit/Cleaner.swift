import Foundation
import Rainbow

public struct Cleaner {
    let path: String
    let flag: String
    let verbose: Bool

    public init(path: String, flag: String, verbose: Bool) {
        self.path = path
        self.flag = flag
        self.verbose = verbose
    }

    public func clean() throws {
        print("Welcome to SwiftFlagCleaner!".underline.bold.blue)
        print("👀 Scanning directory: \(path)".italic.lightBlue)
        print("👀 Searching for files containing: \"\(flag)\"".italic.lightBlue)

        let startTime = Date()

        // Find ripgrep path first, as we'll use it for both file collection and content search
        let rgPath = try findRipgrepPath()

        let files = try collectSourceFiles(at: path, usingRipgrep: rgPath != nil, ripgrepPath: rgPath)
        let matchingFiles = try findFilesContainingString(directory: path, flag: flag, ripgrepPath: rgPath)

        if verbose {
            print("Found \(matchingFiles.count) matching source files out of \(files.count) total:".lightBlue)
        }

        // Process the matching files
        let objcCleaner = ObjcCleaner(fileManager: FileManager.default, verbose: verbose)
        let swiftCleaner = SwiftCleaner(fileManager: FileManager.default, verbose: verbose)
        var processedCount = 0
        var successCount = 0

        print("Processing matching files...".blue.underline)

        for filePath in matchingFiles {
            processedCount += 1

            if filePath.hasSuffix(".m") || filePath.hasSuffix(".mm") || filePath.hasSuffix(".h") {
                do {
                    if try objcCleaner.processFile(at: filePath, flag: flag) {
                        successCount += 1
                    }
                } catch {
                    print("Error processing \(filePath): \(error.localizedDescription)".red)
                }
            } else if filePath.hasSuffix(".swift") {
                do {
                    if try swiftCleaner.processFile(at: filePath, flag: flag) {
                        successCount += 1
                    }
                } catch {
                    print("Error processing \(filePath): \(error.localizedDescription)".red)
                }
            }
        }

        // Collect all unchanged files from both cleaners
        let unchangedFiles = objcCleaner.unchangedFiles + swiftCleaner.unchangedFiles

        let timeElapsed = Date().timeIntervalSince(startTime)
        print("Successfully processed \(successCount) out of \(processedCount) files.".green.bold)
        print("Total processing time: \(String(format: "%.2f", timeElapsed)) seconds".green)

        // Report files that had no changes
        if !unchangedFiles.isEmpty {
            print("\n⚠️ The following \(unchangedFiles.count) files were matched but had no changes:".yellow.bold)
            print("These files may need manual review as they might contain the flag in a different format:".yellow)

            // Group files by extension for better organization
            let groupedByExtension = Dictionary(grouping: unchangedFiles) { path -> String in
                let components = path.components(separatedBy: ".")
                if components.count > 1, let ext = components.last {
                    return ".\(ext)"
                }
                return "Unknown"
            }

            // Print files grouped by extension
            for (ext, files) in groupedByExtension.sorted(by: { $0.key < $1.key }) {
                print("\n\(ext) files (\(files.count)):".bold.underline)
                for (_, file) in files.sorted().enumerated() {
                    print(" - \(file)".lightYellow)
                }
            }
        }
    }

    /// Finds the ripgrep executable path
    /// - Returns: Path to ripgrep if found, nil otherwise
    func findRipgrepPath() throws -> String? {
        // Find the path to ripgrep by checking common installation locations
        let rgPaths = [
            "/usr/local/bin/rg",     // Homebrew on Intel Macs
            "/opt/homebrew/bin/rg",  // Homebrew on Apple Silicon Macs
            "/usr/bin/rg"            // System-wide installation
        ]

        let rgPath = rgPaths.first { FileManager.default.fileExists(atPath: $0) }

        // Only try to install if ripgrep is not found
        if rgPath == nil {
            if verbose {
                print("ripgrep not found in common locations. Checking if it's available in PATH...".italic.lightRed)
            }

            // Check if ripgrep is in PATH
            let whichTask = Process()
            whichTask.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            whichTask.arguments = ["rg"]

            let outputPipe = Pipe()
            whichTask.standardOutput = outputPipe
            whichTask.standardError = Pipe() // Silence errors

            try whichTask.run()
            whichTask.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let foundPath = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            // If rg is not in PATH and we haven't installed it before, offer to install
            if whichTask.terminationStatus != 0 || foundPath?.isEmpty == true {
                print("ripgrep not found. Would you like to install ripgrep for better search performance? (y/n)".bold.lightRed)
                let response = readLine()?.lowercased()

                if response == "y" || response == "yes" {
                    print("Attempting to install ripgrep using Homebrew...".italic.lightBlue)

                    let brewInstallTask = Process()
                    brewInstallTask.executableURL = URL(fileURLWithPath: "/bin/sh")
                    brewInstallTask.arguments = ["-c", "which brew > /dev/null && brew install ripgrep || echo 'Homebrew not found. Please install ripgrep manually: https://github.com/BurntSushi/ripgrep#installation'"]

                    try brewInstallTask.run()
                    brewInstallTask.waitUntilExit()

                    // Check if installation succeeded
                    for path in rgPaths {
                        if FileManager.default.fileExists(atPath: path) {
                            if verbose {
                                print("ripgrep successfully installed at \(path)".lightBlue)
                            }
                            return path
                        }
                    }
                }

                // If installation failed or user declined
                return nil
            } else if let path = foundPath, !path.isEmpty {
                // Use the found path
                if verbose {
                    print("Found ripgrep in PATH at: \(path)".lightBlue)
                }
                return path
            }
        }

        return rgPath
    }

    /// Collects all Swift and Objective-C files from a directory recursively
    /// - Parameters:
    ///   - directory: Path to the directory to scan
    ///   - usingRipgrep: Whether to use ripgrep for file collection
    ///   - ripgrepPath: Path to ripgrep executable, if available
    /// - Returns: Array of file paths for Swift and Objective-C files
    func collectSourceFiles(at directory: String, usingRipgrep: Bool, ripgrepPath: String?) throws -> [String] {
        let fileManager = FileManager.default

        // Make sure the directory exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw NSError(
                domain: "Cleaner",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Path does not exist or is not a directory: \(directory)"
                ]
            )
        }

        // Get all items in the directory
        var sourceFiles: [String] = []

        if usingRipgrep, let rgPath = ripgrepPath {
            if verbose {
                print("Finding source files using ripgrep...".italic.lightBlue)
            }

            // Use ripgrep to find Swift and Objective-C files
            let rgTask = Process()
            rgTask.executableURL = URL(fileURLWithPath: rgPath)
            rgTask.arguments = [
                "--files",
                "--type", "swift",
                "--type", "objc",
                directory
            ]

            let outputPipe = Pipe()
            rgTask.standardOutput = outputPipe

            try rgTask.run()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let fileList = String(data: outputData, encoding: .utf8) {
                sourceFiles = fileList.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
            }

            rgTask.waitUntilExit()
        } else {
            if verbose {
                print("Finding source files using find command...".italic.lightBlue)
            }

            // Fallback to find command
            let findTask = Process()
            findTask.executableURL = URL(fileURLWithPath: "/bin/sh")
            findTask.arguments = [
                "-c",
                "find \"\(directory)\" -type f \\( -name \"*.swift\" -o -name \"*.m\" -o -name \"*.mm\" -o -name \"*.h\" \\) -not -path \"*/*.bundle/*\""
            ]

            let outputPipe = Pipe()
            findTask.standardOutput = outputPipe

            try findTask.run()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let fileList = String(data: outputData, encoding: .utf8) {
                sourceFiles = fileList.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
            }

            findTask.waitUntilExit()
        }

        return sourceFiles
    }

    /// Uses ripgrep or grep to find files containing the specified string
    /// - Parameters:
    ///   - directory: Path to the directory to search
    ///   - flag: String to search for in each file
    ///   - ripgrepPath: Path to ripgrep executable, if available
    /// - Returns: Array of file paths that contain the search string
    func findFilesContainingString(directory: String, flag: String, ripgrepPath: String?) throws -> [String] {
        // If ripgrep path is available, use it
        if let rgPath = ripgrepPath {
            if verbose {
                print("Using ripgrep to search for \"\(flag)\" in files...".italic.lightBlue)
            }

            let rgTask = Process()
            rgTask.executableURL = URL(fileURLWithPath: rgPath)

            rgTask.arguments = [
                "--files-with-matches",  // Only show names of files containing matches
                "--hidden",              // Search hidden files too
                "-F",                    // Treat the pattern as a literal string
                "--type", "swift",       // Only Swift files
                "--type", "objc",        // And Objective-C files
                "--no-messages",         // Suppress error messages
                flag,
                directory                // Search directly in the directory
            ]

            let searchStartTime = Date()
            if verbose {
                print("Running ripgrep command: \(rgPath) \(rgTask.arguments?.joined(separator: " ") ?? "")".italic)
                print("Searching for pattern: \"\(flag)\" in directory: \(directory)".italic)
            }

            defer {
                // Print the time taken for the search
                if verbose {
                    let searchTime = Date().timeIntervalSince(searchStartTime)
                    print("Ripgrep search completed in \(String(format: "%.2f", searchTime)) seconds".blue.bold)
                }
            }

            let outputPipe = Pipe()
            rgTask.standardOutput = outputPipe
            let errorPipe = Pipe()
            rgTask.standardError = errorPipe

            try rgTask.run()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            var matchingFiles: [String] = []

            if let output = String(data: outputData, encoding: .utf8) {
                matchingFiles = output.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }

                if verbose && !matchingFiles.isEmpty {
                    print("First few matching files:")
                    // Show just the first 5 matches for quick visual feedback
                    for (index, file) in matchingFiles.prefix(5).enumerated() {
                        print("  \(index + 1). \(file)")
                    }
                    if matchingFiles.count > 5 {
                        print("  ... and \(matchingFiles.count - 5) more files")
                    }
                }
            }

            // Filter out and handle any "No such file or directory" errors appropriately
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                // Filter out common "No such file or directory" errors for more concise output
                let relevantErrors = errorOutput
                    .components(separatedBy: .newlines)
                    .filter { !$0.contains("No such file or directory") && !$0.isEmpty }
                    .joined(separator: "\n")

                if !relevantErrors.isEmpty && verbose {
                    print("Ripgrep reported the following messages:".lightRed)
                    print(relevantErrors)
                }
            }

            rgTask.waitUntilExit()

            if verbose {
                print("Ripgrep process exited with status: \(rgTask.terminationStatus)".lightRed)
            }

            // No need for temporary file cleanup
            return matchingFiles
        } else {
            // Use grep as fallback
            if verbose {
                print("Using grep to search for \"\(flag)\" in files...".lightBlue)
                print("Note: For better performance, consider installing ripgrep".lightBlue)
            }
            return try fallbackToGrep(directory: directory, flag: flag)
        }
    }

    /// Fallback method to use grep if ripgrep is not available
    private func fallbackToGrep(directory: String, flag: String) throws -> [String] {
        let grepTask = Process()
        grepTask.executableURL = URL(fileURLWithPath: "/bin/sh")
        grepTask.arguments = [
            "-c",
            "find \"\(directory)\" -type f \\( -name \"*.swift\" -o -name \"*.m\" -o -name \"*.mm\" -o -name \"*.h\" \\) -not -path \"*/*.bundle/*\" | xargs grep -l \"\(flag.replacingOccurrences(of: "\"", with: "\\\""))\""
        ]

        let outputPipe = Pipe()
        grepTask.standardOutput = outputPipe

        try grepTask.run()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        var matchingFiles: [String] = []

        if let output = String(data: outputData, encoding: .utf8) {
            matchingFiles = output.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
        }

        grepTask.waitUntilExit()

        return matchingFiles
    }
}
