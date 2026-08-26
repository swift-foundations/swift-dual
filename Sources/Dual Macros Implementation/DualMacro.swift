import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct DualMacro {}

extension DualMacro {
    enum Diagnostic: String, DiagnosticMessage {
        case requiresStructOrEnum
        case noEnumCases
        case coAttachedWithCases
    }
}

extension DualMacro.Diagnostic {
    var message: String {
        switch self {
        case .requiresStructOrEnum:
            "@Dual can only be applied to structs or enums"

        case .noEnumCases:
            "@Dual requires an enum containing at least one case"

        case .coAttachedWithCases:
            "@Dual and @Cases must not be attached to the same declaration"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "DualMacro", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}

extension DualMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext

    ) throws -> [DeclSyntax] {
        guard !hasAttribute(declaration, named: "Cases") else {
            context.diagnose(
                SwiftDiagnostics.Diagnostic(
                    node: node,
                    message: Diagnostic.coAttachedWithCases
                )
            )
            return []
        }

        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return expand(enumDecl, node: node, context: context)
        }

        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return expand(structDecl, node: node, context: context)
        }

        context.diagnose(
            SwiftDiagnostics.Diagnostic(
                node: node,
                message: Diagnostic.requiresStructOrEnum
            )
        )
        return []
    }
}

extension DualMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext

    ) throws -> [AttributeSyntax] {

        guard !hasAttribute(declaration, named: "Cases") else { return [] }
        if declaration.is(EnumDeclSyntax.self) { return [] }

        guard let varDecl = member.as(VariableDeclSyntax.self),
            let binding = varDecl.bindings.first,
            binding.accessorBlock == nil,
            binding.pattern.is(IdentifierPatternSyntax.self),
            binding.typeAnnotation != nil
        else {
            return []
        }

        guard let structDecl = declaration.as(StructDeclSyntax.self) else { return [] }

        let isPublicStruct = structDecl.modifiers.contains {
            $0.name.tokenKind == .keyword(.public)
        }
        let isPublicMember = varDecl.modifiers.contains { $0.name.tokenKind == .keyword(.public) }

        if isPublicStruct && !isPublicMember && !hasRestrictedAccess(varDecl.modifiers) {
            return [AttributeSyntax(stringLiteral: "@usableFromInline")]
        }
        return []
    }
}

extension DualMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext

    ) throws -> [ExtensionDeclSyntax] {

        guard !hasAttribute(declaration, named: "Cases") else { return [] }
        guard declaration.is(EnumDeclSyntax.self) else { return [] }
        return [
            try ExtensionDeclSyntax(
                "extension \(type.trimmed): Optic.__OpticPrismAccessible {}"
            )
        ]
    }
}
