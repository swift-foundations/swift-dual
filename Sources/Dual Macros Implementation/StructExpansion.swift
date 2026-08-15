import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Property Extraction

struct Property {
    /// The identifier text as it appears in source, including backtick escaping.
    let name: String
    let type: String
    let isVar: Bool
}

func extractProperties(from structDecl: StructDeclSyntax) -> [Property] {
    structDecl.memberBlock.members.flatMap { member -> [Property] in
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
            !varDecl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) })
        else {
            return []
        }

        let isVar = varDecl.bindingSpecifier.tokenKind == .keyword(.var)
        let isLet = varDecl.bindingSpecifier.tokenKind == .keyword(.let)
        guard isVar || isLet else { return [] }

        return varDecl.bindings.compactMap { binding in
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                let typeAnnotation = binding.typeAnnotation,
                binding.accessorBlock == nil
            else { return nil }

            // .text preserves backtick escaping — use directly, do NOT re-escape.
            return Property(
                name: identifier.identifier.text,
                type: typeAnnotation.type.trimmedDescription,
                isVar: isVar
            )
        }
    }
}

// MARK: - Struct → Dual Enum Expansion

func expand(
    _ structDecl: StructDeclSyntax,
    node: AttributeSyntax,
    context: some MacroExpansionContext
) -> [DeclSyntax] {
    let properties = extractProperties(from: structDecl)
    let isPublic = isPublicDecl(structDecl)
    let inlinable = isPublic && canInline(from: structDecl.memberBlock)
    let sendable = isSendable(structDecl)
    let access = isPublic ? "public " : ""
    let inline = inlinable ? "@inlinable\n        " : ""

    var result: [DeclSyntax] = []

    // 1. Build the Dual enum
    var body: [String] = []

    // Case declarations
    for prop in properties {
        body.append("case \(prop.name)(\(prop.type))")
    }

    // Extraction properties — wrap type in parens for closure types:
    // `(@Sendable (Int) -> String)?` not `@Sendable (Int) -> String?`
    for prop in properties {
        body.append(
            "\(inline)\(access)var \(prop.name): (\(prop.type))? { if case .\(prop.name)(let v) = self { v } else { nil } }"
        )
    }

    // Case discriminant
    let caseNames = properties.map(\.name)
    body.append(generateCaseDiscriminant(caseNames: caseNames, isPublic: isPublic))

    // var case: Case
    let caseCases = properties.map { "case .\($0.name): .\($0.name)" }
        .joined(separator: "\n            ")

    body.append(
        """
            \(inline)\(access)var `case`: Case {
                    switch self {
                    \(caseCases)
                    }
                }
        """
    )

    // Prisms struct
    let prisms = properties.map { prop in
        generatePrism(
            for: PrismCase(
                caseName: prop.name,
                rootTypeName: "Dual",
                parameters: [(label: nil, type: prop.type)]
            )
        )
    }.joined(separator: "\n\n        ")

    body.append(
        """
            \(access)struct Prisms: Sendable {
                    \(inline)\(access)init() {}

                    \(prisms)
                }
        """
    )

    // static var prisms, is(_:), subscript[prism:], modify(_:_:)
    body.append("\(inline)\(access)static var prisms: Prisms { Prisms() }")

    body.append(
        """
            \(inline)\(access)func `is`<Value>(_ keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<Dual, Value>>) -> Bool {
                    Self.prisms[keyPath: keyPath].extract(self) != nil
                }
        """
    )

    body.append(
        """
            \(inline)\(access)subscript<Value>(prism keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<Dual, Value>>) -> Value? {
                    Self.prisms[keyPath: keyPath].extract(self)
                }
        """
    )

    // An empty struct yields a zero-case (uninhabited) Dual and an empty `Prisms`,
    // so no `KeyPath<Prisms, Prism<Dual, Value>>` can be formed and `modify` is
    // uninvokable. Emit an empty body to avoid an unreachable `self = prism.embed(value)`
    // ("will never be executed", since `embed` would produce a value of the uninhabited Dual).
    if properties.isEmpty {
        body.append(
            """
                \(inline)\(access)mutating func modify<Value>(_ keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<Dual, Value>>, _ transform: (inout Value) -> Void) {}
            """
        )
    } else {
        body.append(
            """
                \(inline)\(access)mutating func modify<Value>(_ keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<Dual, Value>>, _ transform: (inout Value) -> Void) {
                        let prism = Self.prisms[keyPath: keyPath]
                        guard var value = prism.extract(self) else { return }
                        transform(&value)
                        self = prism.embed(value)
                    }
            """
        )
    }

    let inheritance =
        sendable
        ? ": Sendable, Optic_Primitives.__OpticPrismAccessible"
        : ": Optic_Primitives.__OpticPrismAccessible"

    let dualEnum: DeclSyntax = """
        \(raw: access)enum Dual\(raw: inheritance) {
            \(raw: body.joined(separator: "\n\n        "))
        }
        """
    result.append(dualEnum)

    // 2. Homogeneous subscript on the source struct
    let uniqueTypes = Set(properties.map(\.type))
    if uniqueTypes.count == 1, let sharedType = properties.first?.type {
        let getCases = properties.map { "case .\($0.name): self.\($0.name)" }
            .joined(separator: "\n                ")

        if properties.allSatisfy(\.isVar) {
            let setCases = properties.map { "case .\($0.name): self.\($0.name) = newValue" }
                .joined(separator: "\n                ")

            let subscriptDecl: DeclSyntax = """
                \(raw: inline)\(raw: access)subscript(`case` c: Dual.Case) -> \(raw: sharedType) {
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
            result.append(subscriptDecl)
        } else {
            let subscriptDecl: DeclSyntax = """
                \(raw: inline)\(raw: access)subscript(`case` c: Dual.Case) -> \(raw: sharedType) {
                    switch c {
                    \(raw: getCases)
                    }
                }
                """
            result.append(subscriptDecl)
        }
    }

    return result
}
