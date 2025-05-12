import SwiftSyntax
import SwiftParser

public typealias FlagString = String

final public class SwiftCleanerRewriter: SyntaxRewriter {
    public private(set) var isEdited: Bool = false
    public let flag: FlagString

    public init(flag: String) {
        self.flag = flag
    }

     public override func visit(_ node: IfConfigDeclSyntax) -> DeclSyntax {
         // Skip processing if this conditional block doesn't match our target flag
         guard node.clauses.isSupported(for: flag) else {
             return super.visit(node)
         }

         isEdited = true

         if let enabledClause = node.clauses.getEnableClause(flag: flag) {
             if let elements = enabledClause.elements {
                 // Process leading whitespace to maintain proper formatting
                 let leadingTriviaPieces: [TriviaPiece] = {
                     var pieces = elements.leadingTrivia.pieces
                     if case let .newlines(count) = pieces.first {
                         if count > 1 {
                             pieces[0] = .newlines(count - 1)
                         }
                         else {
                             pieces = Array(pieces.dropFirst())
                         }
                     }
                     return pieces
                 }()

                 // Replace the conditional compilation block with its contents directly
                 // We use MissingDeclSyntax as a way to inject arbitrary code into the AST
                 return DeclSyntax(
                     MissingDeclSyntax(
                         leadingTrivia: node.leadingTrivia,
                         placeholder: .unknown(
                             // Use the actual content from inside the #if block
                             // but strip any extra whitespace with trimmed
                             elements.trimmed.description,
                             // Apply carefully adjusted whitespace to maintain formatting
                             leadingTrivia: .init(pieces: leadingTriviaPieces)
                         ),
                         trailingTrivia: nil
                     )
                 )
             }
             else {
                 // Handle empty conditional blocks by creating an empty declaration
                 // This removes the entire #if/#endif construct when there's no content
                 return DeclSyntax(
                     MissingDeclSyntax(
                         leadingTrivia: node.leadingTrivia,
                         placeholder: .identifier(""),
                         trailingTrivia: node.trailingTrivia
                     )
                 )
             }
         }
         else {
             // No enabled clause was found, so create an empty declaration
             // This effectively removes the conditional compilation block
             return DeclSyntax(
                 MissingDeclSyntax(
                     leadingTrivia: node.leadingTrivia,
                     placeholder: .identifier(""),
                     trailingTrivia: node.trailingTrivia
                 )
             )
         }
     }
}

extension IfConfigClauseListSyntax {
    public var clauses: [IfConfigClauseSyntax] {
        var clauses = [IfConfigClauseSyntax]()
        forEach { clauseSyntax in
            clauses.append(clauseSyntax)
        }
        return clauses
    }

    public func getEnableClause(flag: String) -> IfConfigClauseSyntax? {
        for clause in clauses {
            if (
                clause.poundKeyword.tokenKind == .poundIf || // #if
                    clause.poundKeyword.tokenKind == .poundElseif
            ) // #elif
                && clause.isEnabledClause(flag: flag) {
                return clause
            }
            else if clause.poundKeyword.tokenKind == .poundElse {
                return clause
            }
        }
        return nil
    }

    public func isSupported(for flag: FlagString) -> Bool {
        var flags = Set<String>()

        var stack = clauses.compactMap { $0.condition }
        while stack.isEmpty == false {
            let condition = stack.popLast()!

            if let declReferenceExpr = condition.as(DeclReferenceExprSyntax.self) {
                flags.insert(declReferenceExpr.trimmed.description)
            }
            else if let prefixOperatorExpr = condition.as(PrefixOperatorExprSyntax.self) {
                stack.append(prefixOperatorExpr.expression)
            }
            else if let infixOperatorExpr = condition.as(InfixOperatorExprSyntax.self) {
                stack.append(infixOperatorExpr.leftOperand)
                stack.append(infixOperatorExpr.rightOperand)
            }
            else if let labledExpr = condition.as(LabeledExprSyntax.self) {
                stack.append(labledExpr.expression)
            }
            else if let labledListExpr = condition.as(LabeledExprListSyntax.self) {
                labledListExpr.forEach { stack.append($0.expression) }
            }
            else if let tupleExpr = condition.as(TupleExprSyntax.self) {
                tupleExpr.elements.forEach { stack.append($0.expression) }
            }
        }

        return flags.contains(flag) && flags.count == 1
    }
}

extension IfConfigClauseSyntax {
    public func isEnabledClause(flag: String) -> Bool {
        guard let condition = condition else { return true }

        var stack = [String]()

        let flagChecker: (String) -> Bool = { flag in
            (Int(flag) ?? 1) > 0
        }

        func append(newFlag: String) {
            let isFlagEnabled = flagChecker(newFlag)
            guard let last = stack.last, ["&&", "||", "!"].contains(stack.last) else {
                stack.append(isFlagEnabled ? "1" : "0")
                return
            }

            if last == "&&" {
                stack.removeLast() // Remove `&&`
                let prevCondition = stack.removeLast()
                append(newFlag: (flagChecker(prevCondition) && isFlagEnabled) ? "1" : "0")
            }
            else if last == "||" {
                stack.removeLast() // Remove `||`
                let prevCondition = stack.removeLast()
                append(newFlag: (flagChecker(prevCondition) || isFlagEnabled) ? "1" : "0")
            }
            else if last == "!" {
                stack.removeLast() // Remove `!`
                append(newFlag: isFlagEnabled ? "0" : "1")
            }
        }

        for token in condition.tokens(viewMode: .all) {
            switch token.tokenKind {
            case let .prefixOperator(prefix):
                stack.append(prefix)
            case .leftParen:
                stack.append(token.text)
            case let .binaryOperator(`operator`):
                stack.append(`operator`)
            case let .integerLiteral(integerString):
                append(newFlag: integerString)
            case let .identifier(flag):
                append(newFlag: flag)
            case .rightParen:
                guard let flag = stack.last else { continue }
                var last = stack.removeLast()
                while stack.isEmpty == false && last != "(" {
                    last = stack.removeLast()
                }
                append(newFlag: flag)
            default:
                break
            }
        }

        return (stack.last ?? "1") == "1"
    }
}
