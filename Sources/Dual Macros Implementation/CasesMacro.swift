import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - @Cases
//
// Generates, inside the annotated enum:
//   - `struct Cases { ... one Case_Paths.Case.Path property per case ... }`
//   - `static var cases: Cases`
//   - `func is<Value>(_ keyPath:) -> Bool`
// and, via the extension role, `extension Enum: Case_Paths.CaseAnalyzable {}`.
//
// Ported from Experiments/cases-macro-keypath-feasibility (Spike B), re-rooted on
// swift-dual's real enum-analysis machinery (extractCases / isPublicDecl in
// EnumExpansion.swift / Utilities.swift) and emitting FULLY-QUALIFIED runtime
// references: the @Dual-generated nested `Case` discriminant shadows the top-level
// `Case` namespace inside an annotated enum's scope, so an unqualified `Case.Path`
// would bind to the wrong `Case`.

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

// MARK: - MemberMacro

extension CasesMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
            // Untyped throws forced by external protocol SwiftSyntaxMacros (macro expansion).
            // swiftlint:disable:next typed_throws_required
    ) throws -> [DeclSyntax] {
        guard !hasAttribute(declaration, named: "Dual") else {
            context.diagnose(SwiftDiagnostics.Diagnostic(node: node, message: Message.coAttachedWithDual))
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

// MARK: - ExtensionMacro

extension CasesMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
            // Untyped throws forced by external protocol SwiftSyntaxMacros (macro expansion).
            // swiftlint:disable:next typed_throws_required
    ) throws -> [ExtensionDeclSyntax] {
        // Co-attachment with @Dual is diagnosed by the member role; emit nothing here.
        guard !hasAttribute(declaration, named: "Dual") else { return [] }
        guard declaration.is(EnumDeclSyntax.self) else { return [] }
        return [try ExtensionDeclSyntax("extension \(type.trimmed): Case_Paths.CaseAnalyzable {}")]
    }
}
