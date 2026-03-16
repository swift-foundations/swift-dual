import SwiftSyntax
import SwiftSyntaxBuilder

/// Generates a single extraction computed property for an enum case.
///
/// All name/label arguments are expected to include backtick escaping from the AST
/// (via `.text`). Do NOT re-escape them.
func generateExtractionProperty(
    caseName: String,
    parameters: [(label: String?, type: String)],
    isPublic: Bool
) -> DeclSyntax {
    let accessModifier = isPublic ? "public " : ""
    let inlinableAttr = isPublic ? "@inlinable\n    " : ""

    if parameters.isEmpty {
        return """
            \(raw: inlinableAttr)\(raw: accessModifier)var \(raw: caseName): Void? {
                if case .\(raw: caseName) = self { () } else { nil }
            }
            """
    } else if parameters.count == 1 {
        let param = parameters[0]
        let extractPattern = param.label.map { "\($0): let v" } ?? "let v"
        // Wrap type in parens before Optional to handle closure types:
        // `(@Sendable (Int) -> String)?` not `@Sendable (Int) -> String?`
        let optionalType = "(\(param.type))?"

        return """
            \(raw: inlinableAttr)\(raw: accessModifier)var \(raw: caseName): \(raw: optionalType) {
                if case .\(raw: caseName)(\(raw: extractPattern)) = self { v } else { nil }
            }
            """
    } else {
        let tupleTypes = parameters.map { param in
            if let label = param.label {
                return "\(label): \(param.type)"
            } else {
                return param.type
            }
        }.joined(separator: ", ")

        let extractPatterns = parameters.enumerated().map { index, param in
            if let label = param.label {
                return "\(label): let v\(index)"
            } else {
                return "let v\(index)"
            }
        }.joined(separator: ", ")

        let extractTuple = parameters.enumerated().map { index, param in
            if let label = param.label {
                return "\(label): v\(index)"
            } else {
                return "v\(index)"
            }
        }.joined(separator: ", ")

        return """
            \(raw: inlinableAttr)\(raw: accessModifier)var \(raw: caseName): (\(raw: tupleTypes))? {
                if case .\(raw: caseName)(\(raw: extractPatterns)) = self { (\(raw: extractTuple)) } else { nil }
            }
            """
    }
}

/// Generates the `var case: Case` computed property.
func generateCaseProperty(
    caseNames: [String],
    isPublic: Bool
) -> DeclSyntax {
    let accessModifier = isPublic ? "public " : ""
    let inlinableAttr = isPublic ? "@inlinable\n    " : ""

    let selfCaseCases = caseNames.map { name in
        "case .\(name): .\(name)"
    }.joined(separator: "\n            ")

    return """
        \(raw: inlinableAttr)\(raw: accessModifier)var `case`: Case {
            switch self {
            \(raw: selfCaseCases)
            }
        }
        """
}

/// Generates the Prisms struct containing one prism property per case.
///
/// All name/label arguments are expected to include backtick escaping from the AST.
func generatePrismsStruct(
    cases: [(name: String, parameters: [(label: String?, type: String)])],
    rootTypeName: String,
    isPublic: Bool
) -> DeclSyntax {
    let accessModifier = isPublic ? "public " : ""
    let inlinableAttr = isPublic ? "@inlinable\n        " : ""

    let prismProperties = cases.map { enumCase in
        let prismCase = PrismCase(
            caseName: enumCase.name,
            rootTypeName: rootTypeName,
            parameters: enumCase.parameters.map { ($0.label, $0.type) }
        )
        return generatePrism(for: prismCase)
    }.joined(separator: "\n\n        ")

    return """
        \(raw: accessModifier)struct Prisms: Sendable {
            \(raw: inlinableAttr)\(raw: accessModifier)init() {}

            \(raw: prismProperties)
        }
        """
}

/// Generates: static var prisms, is(_:), subscript[prism:], modify(_:_:)
func generatePrismAccessors(
    rootTypeName: String,
    isPublic: Bool
) -> [DeclSyntax] {
    let accessModifier = isPublic ? "public " : ""
    let inlinableAttr = isPublic ? "@inlinable\n    " : ""

    let prismsProperty: DeclSyntax = """
        \(raw: inlinableAttr)\(raw: accessModifier)static var prisms: Prisms { Prisms() }
        """

    let isMethod: DeclSyntax = """
        \(raw: inlinableAttr)\(raw: accessModifier)func `is`<Value>(_ keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<\(raw: rootTypeName), Value>>) -> Bool {
            Self.prisms[keyPath: keyPath].extract(self) != nil
        }
        """

    let prismSubscript: DeclSyntax = """
        \(raw: inlinableAttr)\(raw: accessModifier)subscript<Value>(prism keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<\(raw: rootTypeName), Value>>) -> Value? {
            Self.prisms[keyPath: keyPath].extract(self)
        }
        """

    let modifyMethod: DeclSyntax = """
        \(raw: inlinableAttr)\(raw: accessModifier)mutating func modify<Value>(_ keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<\(raw: rootTypeName), Value>>, _ transform: (inout Value) -> Void) {
            let prism = Self.prisms[keyPath: keyPath]
            guard var value = prism.extract(self) else { return }
            transform(&value)
            self = prism.embed(value)
        }
        """

    return [prismsProperty, isMethod, prismSubscript, modifyMethod]
}
