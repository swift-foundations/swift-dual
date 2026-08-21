import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CasesMacro {}

extension CasesMacro {
    enum Message: String, DiagnosticMessage {
        case requiresEnum
        case noEnumCases
        case coAttachedWithDual

        var message: String {
            switch self {
            case .requiresEnum: "@Cases can only be applied to an enum"
            case .noEnumCases: "@Cases requires an enum with at least one case"

            case .coAttachedWithDual:
                "@Cases and @Dual must not be attached to the same declaration"
            }
        }
        var diagnosticID: MessageID { MessageID(domain: "CasesMacro", id: rawValue) }
        var severity: DiagnosticSeverity { .error }
    }
}

extension CasesMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext

    ) throws -> [DeclSyntax] {
        guard !hasAttribute(declaration, named: "Dual") else {
            context.diagnose(
                SwiftDiagnostics.Diagnostic(node: node, message: Message.coAttachedWithDual)
            )
            return []
        }
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            context.diagnose(SwiftDiagnostics.Diagnostic(node: node, message: Message.requiresEnum))
            return []
        }
        let cases = extractCases(from: enumDecl)
        guard !cases.isEmpty else {
            context.diagnose(SwiftDiagnostics.Diagnostic(node: node, message: Message.noEnumCases))
            return []
        }
        return generateCasesWitness(
            cases: cases,
            root: enumDecl.name.trimmedDescription,
            isPublic: isPublicDecl(enumDecl)
        )
    }
}

extension CasesMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext

    ) throws -> [ExtensionDeclSyntax] {

        guard !hasAttribute(declaration, named: "Dual") else { return [] }
        guard declaration.is(EnumDeclSyntax.self) else { return [] }
        return [try ExtensionDeclSyntax("extension \(type.trimmed): Case_Paths.CaseAnalyzable {}")]
    }
}
