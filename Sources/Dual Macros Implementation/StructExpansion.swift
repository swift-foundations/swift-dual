import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

// MARK: - Stored Property Extraction

struct StoredProperty {
    /// The identifier text as it appears in source, including backtick escaping if present.
    /// e.g., "host" for `var host: String`, "`condition one`" for `var \`condition one\`: Bool?`
    let name: String
    let type: String
    let isVar: Bool
}

func extractAllStoredProperties(from structDecl: StructDeclSyntax) -> [StoredProperty] {
    var properties: [StoredProperty] = []

    for member in structDecl.memberBlock.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

        let isVar = varDecl.bindingSpecifier.tokenKind == .keyword(.var)
        let isLet = varDecl.bindingSpecifier.tokenKind == .keyword(.let)
        guard isVar || isLet else { continue }

        // Skip static properties
        let isStatic = varDecl.modifiers.contains { $0.name.tokenKind == .keyword(.static) }
        guard !isStatic else { continue }

        for binding in varDecl.bindings {
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation,
                  binding.accessorBlock == nil else { continue }

            // .text preserves backtick escaping — use it directly, do NOT re-escape.
            properties.append(StoredProperty(
                name: identifier.identifier.text,
                type: typeAnnotation.type.trimmedDescription,
                isVar: isVar
            ))
        }
    }

    return properties
}

// MARK: - Struct → Dual Enum Expansion

func expandStruct(
    structDecl: StructDeclSyntax,
    node: AttributeSyntax,
    context: some MacroExpansionContext
) -> [DeclSyntax] {
    let properties = extractAllStoredProperties(from: structDecl)

    guard !properties.isEmpty else {
        context.diagnose(Diagnostic(
            node: node,
            message: DualDiagnostic.noStoredProperties
        ))
        return []
    }

    let structName = structDecl.name.trimmedDescription
    let isPublic = isPublicDecl(structDecl)
    let inlinable = isPublic && canInline(from: structDecl.memberBlock)
    let sendable = isSendable(structDecl)
    let accessModifier = isPublic ? "public " : ""
    let inlinableAttr = inlinable ? "@inlinable\n        " : ""

    var members: [DeclSyntax] = []

    // 1. Build the Dual enum content
    var dualMembers: [String] = []

    // Case declarations — prop.name already includes backtick escaping from the AST
    for prop in properties {
        dualMembers.append("case \(prop.name)(\(prop.type))")
    }

    // Extraction computed properties
    // Wrap type in parens before making Optional to handle closure types correctly:
    // `(@Sendable (Int) -> String)?` not `@Sendable (Int) -> String?`
    for prop in properties {
        let optionalType = "(\(prop.type))?"
        let extraction = "\(inlinableAttr)\(accessModifier)var \(prop.name): \(optionalType) { if case .\(prop.name)(let v) = self { v } else { nil } }"
        dualMembers.append(extraction)
    }

    // Case discriminant — names already escaped from AST
    let caseNames = properties.map(\.name)
    dualMembers.append(generateCaseDiscriminant(caseNames: caseNames, isPublic: isPublic))

    // var case: Case
    let selfCaseCases = properties.map { prop in
        "case .\(prop.name): .\(prop.name)"
    }.joined(separator: "\n            ")

    dualMembers.append("""
        \(inlinableAttr)\(accessModifier)var `case`: Case {
                switch self {
                \(selfCaseCases)
                }
            }
    """)

    // Prisms struct
    let prismProperties = properties.map { prop in
        let prismCase = PrismCase(
            caseName: prop.name,
            rootTypeName: "Dual",
            parameters: [(label: nil, type: prop.type)]
        )
        return generatePrism(for: prismCase)
    }.joined(separator: "\n\n        ")

    dualMembers.append("""
        \(accessModifier)struct Prisms: Sendable {
                \(inlinableAttr)\(accessModifier)init() {}

                \(prismProperties)
            }
    """)

    // static var prisms
    dualMembers.append("\(inlinableAttr)\(accessModifier)static var prisms: Prisms { Prisms() }")

    // is(_:)
    dualMembers.append("""
        \(inlinableAttr)\(accessModifier)func `is`<Value>(_ keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<Dual, Value>>) -> Bool {
                Self.prisms[keyPath: keyPath].extract(self) != nil
            }
    """)

    // subscript[prism:]
    dualMembers.append("""
        \(inlinableAttr)\(accessModifier)subscript<Value>(prism keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<Dual, Value>>) -> Value? {
                Self.prisms[keyPath: keyPath].extract(self)
            }
    """)

    // modify(_:_:)
    dualMembers.append("""
        \(inlinableAttr)\(accessModifier)mutating func modify<Value>(_ keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<Dual, Value>>, _ transform: (inout Value) -> Void) {
                let prism = Self.prisms[keyPath: keyPath]
                guard var value = prism.extract(self) else { return }
                transform(&value)
                self = prism.embed(value)
            }
    """)

    // Build the enum
    let inheritanceClause: String
    if sendable {
        inheritanceClause = ": Sendable, Optic_Primitives.__OpticPrismAccessible"
    } else {
        inheritanceClause = ": Optic_Primitives.__OpticPrismAccessible"
    }

    let dualBody = dualMembers.joined(separator: "\n\n        ")

    let dualEnum: DeclSyntax = """
        \(raw: accessModifier)enum Dual\(raw: inheritanceClause) {
            \(raw: dualBody)
        }
        """
    members.append(dualEnum)

    // 2. Homogeneous subscript on the source struct
    let uniqueTypes = Set(properties.map(\.type))
    if uniqueTypes.count == 1 {
        let sharedType = properties[0].type
        let allVar = properties.allSatisfy(\.isVar)

        let getCases = properties.map { prop in
            "case .\(prop.name): self.\(prop.name)"
        }.joined(separator: "\n                ")

        if allVar {
            let setCases = properties.map { prop in
                "case .\(prop.name): self.\(prop.name) = newValue"
            }.joined(separator: "\n                ")

            let subscriptDecl: DeclSyntax = """
                \(raw: inlinableAttr)\(raw: accessModifier)subscript(`case` c: Dual.Case) -> \(raw: sharedType) {
                    get {
                        switch c {
                        \(raw: getCases)
                        }
                    }
                    set {
                        switch c {
                        \(raw: setCases)
                        }
                    }
                }
                """
            members.append(subscriptDecl)
        } else {
            let subscriptDecl: DeclSyntax = """
                \(raw: inlinableAttr)\(raw: accessModifier)subscript(`case` c: Dual.Case) -> \(raw: sharedType) {
                    switch c {
                    \(raw: getCases)
                    }
                }
                """
            members.append(subscriptDecl)
        }
    }

    return members
}
