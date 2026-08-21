import SwiftSyntax

func hasRestrictedAccess(_ modifiers: DeclModifierListSyntax) -> Bool {
    modifiers.contains {
        $0.name.tokenKind == .keyword(.package) || $0.name.tokenKind == .keyword(.private)
            || $0.name.tokenKind == .keyword(.fileprivate)
    }
}

func canInline(from members: MemberBlockSyntax) -> Bool {
    members.members.allSatisfy { member in
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
            let binding = varDecl.bindings.first,
            binding.accessorBlock == nil
        else { return true }
        return !hasRestrictedAccess(varDecl.modifiers)
    }
}

func isSendable(_ declaration: some DeclGroupSyntax) -> Bool {
    declaration.inheritanceClause?.inheritedTypes.contains { inherited in
        inherited.type.trimmedDescription == "Sendable"
    } ?? false
}

func isPublicDecl(_ declaration: some DeclGroupSyntax) -> Bool {
    declaration.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
}

func hasAttribute(_ declaration: some DeclGroupSyntax, named name: String) -> Bool {
    declaration.attributes.contains { element in
        guard case .attribute(let attribute) = element else { return false }
        return attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == name
    }
}
