import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

// MARK: - DualMacro

public struct DualMacro {}

// MARK: - Diagnostics

enum DualDiagnostic: String, DiagnosticMessage {
    case requiresStructOrEnum
    case noStoredProperties
    case noEnumCases

    var message: String {
        switch self {
        case .requiresStructOrEnum:
            return "@Dual can only be applied to structs or enums"
        case .noStoredProperties:
            return "@Dual requires a struct containing at least one stored property"
        case .noEnumCases:
            return "@Dual requires an enum containing at least one case"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "DualMacro", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}

// MARK: - MemberMacro

extension DualMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return expandEnum(enumDecl: enumDecl, node: node, context: context)
        }

        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return expandStruct(structDecl: structDecl, node: node, context: context)
        }

        context.diagnose(Diagnostic(
            node: node,
            message: DualDiagnostic.requiresStructOrEnum
        ))
        return []
    }
}

// MARK: - MemberAttributeMacro

extension DualMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // No attributes for enum members
        if declaration.is(EnumDeclSyntax.self) {
            return []
        }

        guard let varDecl = member.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              binding.accessorBlock == nil,
              binding.pattern.is(IdentifierPatternSyntax.self),
              binding.typeAnnotation != nil else {
            return []
        }

        var attributes: [AttributeSyntax] = []

        // For public structs, add @usableFromInline to non-public stored properties
        // so that @inlinable generated code can reference them.
        // Skip for properties with restricted access (package/private/fileprivate).
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            let isPublicStruct = structDecl.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
            let isPublicMember = varDecl.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
            if isPublicStruct && !isPublicMember && !hasRestrictedAccess(varDecl.modifiers) {
                attributes.append(AttributeSyntax(stringLiteral: "@usableFromInline"))
            }
        }

        return attributes
    }
}

// MARK: - ExtensionMacro

extension DualMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // For enums, conform the source enum to __OpticPrismAccessible
        // For structs, the conformance goes directly in the enum Dual declaration's inheritance clause
        if declaration.is(EnumDeclSyntax.self) {
            let prismExt = try ExtensionDeclSyntax("extension \(type.trimmed): Optic_Primitives.__OpticPrismAccessible {}")
            return [prismExt]
        }

        return []
    }
}
