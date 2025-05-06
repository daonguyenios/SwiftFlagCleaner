import SwiftSyntax
import SwiftParser

/**
 * A syntax visitor that checks whether a Swift file contains any meaningful code declarations.
 * 
 * This visitor traverses the syntax tree of a Swift file and sets `isEmptyFile` to false
 * if it encounters any type declarations, functions, variables, or other meaningful code.
 * It's used to determine if a file should be kept after flag cleaning operations or if
 * the file ended up empty and can be removed.
 */
public final class EmptyFileCheckingVisitor: SyntaxVisitor {
    /// Indicates whether the file contains any meaningful code declarations.
    /// Starts as true and becomes false when a declaration is encountered.
    public var isEmptyFile: Bool = true
    
    // Each visit method below checks for a specific type of Swift declaration.
    // When a declaration is found, we mark the file as non-empty and skip
    // traversing its children since we already know the file has content.
    
    /// Checks for struct declarations
    public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        isEmptyFile = false
        return .skipChildren
    }

    /// Checks for enum declarations
    public override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        isEmptyFile = false
        return .skipChildren
    }

    /// Checks for protocol declarations
    public override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        isEmptyFile = false
        return .skipChildren
    }

    /// Checks for class declarations
    public override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        isEmptyFile = false
        return .skipChildren
    }

    /// Checks for extension declarations
    public override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        isEmptyFile = false
        return .skipChildren
    }

    /// Checks for actor declarations (Swift concurrency)
    public override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        isEmptyFile = false
        return .skipChildren
    }

    /// Checks for typealias declarations
    public override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        isEmptyFile = false
        return .skipChildren
    }

    /// Checks for function declarations (including methods)
    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        isEmptyFile = false
        return .skipChildren
    }

    /// Checks for variable and constant declarations
    public override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        isEmptyFile = false
        return .skipChildren
    }

    /// Checks for macro declarations (Swift 5.9+)
    public override func visit(_ node: MacroDeclSyntax) -> SyntaxVisitorContinueKind {
        isEmptyFile = false
        return .skipChildren
    }

    /// Checks for macro expansion declarations
    public override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        isEmptyFile = false
        return .skipChildren
    }
}
