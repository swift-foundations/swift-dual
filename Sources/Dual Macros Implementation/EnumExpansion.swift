import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Case Extraction

struct Case: Sendable {
    let name: String
    let parameters: [Parameter]

    struct Parameter: Sendable {
        let label: String?
        let type: String
    }
}

func extractCases(from enumDecl: EnumDeclSyntax) -> [Case] {
    enumDecl.memberBlock.members.flatMap { member -> [Case] in
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { return [] }

        return caseDecl.elements.map { element in
            // .text preserves backtick escaping — use directly, do NOT re-escape.
            Case(
                name: element.name.text,
                parameters: element.parameterClause?.parameters.map { param in
                    Case.Parameter(label: param.firstName?.text, type: param.type.trimmedDescription)
                } ?? []
            )
        }
    }
}

// MARK: - Enum → Dual<R> Struct + Infrastructure Expansion

func expand(
    _ enumDecl: EnumDeclSyntax,
    node: AttributeSyntax,
    context: some MacroExpansionContext
) -> [DeclSyntax] {
    let cases = extractCases(from: enumDecl)

    guard !cases.isEmpty else {
        context.diagnose(
            Diagnostic(
                node: node,
                message: DualMacro.Diagnostic.noEnumCases
            )
        )
        return []
    }

    let enumName = enumDecl.name.trimmedDescription
    let isPublic = isPublicDecl(enumDecl)
    let sendable = isSendable(enumDecl)
    let access = isPublic ? "public " : ""
    let inline = isPublic ? "@inlinable\n    " : ""
    let sendableAnnotation = sendable ? "@Sendable " : ""

    var members: [DeclSyntax] = []

    // 1. Dual<R> struct (Scott encoding)
    let dualProperties = cases.map { c in
        let closureParams: String
        if c.parameters.isEmpty {
            closureParams = "()"
        } else {
            closureParams =
                "("
                + c.parameters.map { p in
                    let label = p.label != nil ? "_ \(p.label!): " : "_ arg: "
                    return c.parameters.count == 1 ? "\(label)\(p.type)" : "_ \(p.label ?? "_"): \(p.type)"
                }.joined(separator: ", ") + ")"
        }
        return "\(access)var \(c.name): \(sendableAnnotation)\(closureParams) -> R"
    }.joined(separator: "\n        ")

    let initParams = cases.map { c in
        let closureParams: String
        if c.parameters.isEmpty {
            closureParams = "()"
        } else {
            closureParams =
                "("
                + c.parameters.map { p in
                    let label = p.label != nil ? "_ \(p.label!): " : "_ arg: "
                    return c.parameters.count == 1 ? "\(label)\(p.type)" : "_ \(p.label ?? "_"): \(p.type)"
                }.joined(separator: ", ") + ")"
        }
        return "\(c.name): @escaping \(sendableAnnotation)\(closureParams) -> R"
    }.joined(separator: ",\n            ")

    let initAssignments = cases.map { "self.\($0.name) = \($0.name)" }
        .joined(separator: "\n            ")

    let dualStruct: DeclSyntax = """
        \(raw: access)struct Dual<R> {
            \(raw: dualProperties)

            \(raw: inline)\(raw: access)init(
                \(raw: initParams)
            ) {
                \(raw: initAssignments)
            }
        }
        """
    members.append(dualStruct)

    // 2. match function
    let matchCases = cases.map { c in
        if c.parameters.isEmpty {
            return "case .\(c.name): dual.\(c.name)()"
        } else if c.parameters.count == 1 {
            let p = c.parameters[0]
            let binding = p.label != nil ? "let \(p.label!)" : "let v"
            return "case .\(c.name)(\(binding)): dual.\(c.name)(\(p.label ?? "v"))"
        } else {
            let bindings = c.parameters.enumerated().map { i, p in
                p.label != nil ? "let \(p.label!)" : "let v\(i)"
            }.joined(separator: ", ")
            let args = c.parameters.enumerated().map { i, p in
                p.label ?? "v\(i)"
            }.joined(separator: ", ")
            return "case .\(c.name)(\(bindings)): dual.\(c.name)(\(args))"
        }
    }.joined(separator: "\n            ")

    let matchFunc: DeclSyntax = """
        \(raw: inline)\(raw: access)func match<R>(_ dual: Dual<R>) -> R {
            switch self {
            \(raw: matchCases)
            }
        }
        """
    members.append(matchFunc)

    // 3. Enum infrastructure

    // Extraction properties
    for c in cases {
        members.append(
            generateExtractionProperty(
                caseName: c.name,
                parameters: c.parameters.map { ($0.label, $0.type) },
                isPublic: isPublic
            )
        )
    }

    // Case discriminant
    let caseNames = cases.map(\.name)
    let caseDiscriminant: DeclSyntax = "\(raw: generateCaseDiscriminant(caseNames: caseNames, isPublic: isPublic))"
    members.append(caseDiscriminant)

    // var case: Case
    members.append(
        generateCaseProperty(
            caseNames: caseNames,
            isPublic: isPublic
        )
    )

    // Prisms struct
    members.append(
        generatePrismsStruct(
            cases: cases.map { ($0.name, $0.parameters.map { ($0.label, $0.type) }) },
            rootTypeName: enumName,
            isPublic: isPublic
        )
    )

    // Prism accessors
    members.append(
        contentsOf: generatePrismAccessors(
            rootTypeName: enumName,
            isPublic: isPublic
        )
    )

    return members
}
