import ArgumentParser
import Foundation
import SwiftFlagCleanerKit

@main
struct SwiftFlagCleaner: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A utility for cleaning flags in Swift and Objective-C files",
        discussion: "Scans a directory for Swift and Objective-C files and processes them."
    )
    
    @Option(name: [.customShort("p"), .long], help: "Path to the directory containing Swift and Objective-C files")
    var path: String = FileManager.default.currentDirectoryPath
    
    @Option(name: [.customShort("f"), .long], help: "Flag need to clean in source files")
    var flag: String
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false
    
    func run() throws {
        try Cleaner(path: path, flag: flag, verbose: verbose).clean()
    }
}
