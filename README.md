# SwiftFlagCleaner

SwiftFlagCleaner is a robust command-line tool designed to parse and manipulate Swift and Objective-C code to remove feature flags and clean up related code. It leverages the powerful SwiftSyntax and SwiftParser libraries for Swift code analysis and manipulation, while also handling Objective-C files.

## Features

- Efficiently scan and process Swift and Objective-C source files
- Remove feature flags and related code blocks
- Clean up unnecessary conditional statements
- Optimize source code by removing unused feature flag code
- Support for both Swift and Objective-C codebases
- High-performance file scanning using ripgrep (with graceful fallback to grep)
- Detailed reporting of processing results
- Verbose mode for debugging and detailed analysis

## Installation

To install SwiftFlagCleaner, you need to have Swift installed on your machine. You can clone the repository and build the project using Swift Package Manager.

```bash
git clone https://github.com/daonguyenios/SwiftFlagCleaner.git
cd SwiftFlagCleaner
swift build -c release
```

For convenience, you can copy the compiled binary to a location in your PATH:

```bash
cp .build/release/flagcleaner /usr/local/bin/
```

## Usage

Run the SwiftFlagCleaner tool from the command line with the following syntax:

```bash
SwiftFlagCleaner --path /path/to/source --flag "FLAG_TO_CLEAN"
```

### Options

- `--path, -p`: Path to the directory containing Swift and Objective-C files (defaults to current directory)
- `--flag, -s`: Flag needs to clean in source files (required)
- `--verbose, -v`: Enable verbose output for detailed processing information
- `--help, -h`: Display help information

### Examples

Clean up `FEATURE_FLAG_NAME` flag from a project:

```bash
flagcleaner -p /path/to/project -s "FEATURE_FLAG_NAME"
```

With verbose output:

```bash
flagcleaner -p /path/to/project -s "FEATURE_FLAG_NAME" -v
```

## How It Works

FlagCleaner first scans the specified directory for Swift and Objective-C files containing the specified flag. It then processes each file by:

1. For Swift files: Using SwiftSyntax to parse the file and rewrite code to remove the flag and related code
2. For Objective-C files: Processing the file to remove flag-related preprocessor directives and code

The tool provides detailed output about processed files, including which files were changed and which had matches but no changes were made.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any enhancements or bug fixes.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.
