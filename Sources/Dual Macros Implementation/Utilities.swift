import SwiftSyntax

/// Whether modifiers include package, private, or fileprivate access.
func hasRestrictedAccess(_ modifiers: DeclModifierListSyntax) -> Bool {
    modifiers.contains {
        $0.name.tokenKind == .keyword(.package) ||
        $0.name.tokenKind == .keyword(.private) ||
        $0.name.tokenKind == .keyword(.fileprivate)
    }
}

/// Whether all stored properties in the declaration are publicly accessible.
/// When false, generated members cannot be @inlinable (they reference private storage).
func canInline(from members: MemberBlockSyntax) -> Bool {
    members.members.allSatisfy { member in
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              binding.accessorBlock == nil else { return true }
        return !hasRestrictedAccess(varDecl.modifiers)
    }
}

/// Whether the declaration's inheritance clause includes Sendable.
func isSendable(_ declaration: some DeclGroupSyntax) -> Bool {
    declaration.inheritanceClause?.inheritedTypes.contains { inherited in
        inherited.type.trimmedDescription == "Sendable"
    } ?? false
}

/// Whether the declaration has public access.
func isPublicDecl(_ declaration: some DeclGroupSyntax) -> Bool {
    declaration.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
}
