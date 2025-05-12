import Foundation

public protocol FileManagerProtocol {
    var currentDirectoryPath: String { get }

    func fileExists(atPath path: String) -> Bool
    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool

    func removeItem(atPath path: String) throws
    func write(_ content: any StringProtocol, to url: URL, atomically useAuxiliaryFile: Bool, encoding enc: String.Encoding) throws
    func read(contentsOf url: URL, encoding enc: String.Encoding) throws -> String
}

extension FileManager: FileManagerProtocol {
    public func write(
        _ content: any StringProtocol,
        to url: URL,
        atomically useAuxiliaryFile: Bool,
        encoding enc: String.Encoding
    ) throws {
        try content.write(
            to: url,
            atomically: useAuxiliaryFile,
            encoding: enc
        )
    }

    public func read(contentsOf url: URL, encoding enc: String.Encoding) throws -> String {
        try String(contentsOf: url, encoding: enc)
    }
}
