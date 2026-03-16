import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

// MARK: - Enum Case Extraction

struct EnumCase: Sendable {
    /// The case name as it appears in source, including backtick escaping if present.
    let name: String
    let parameters: [EnumCaseParameter]
}

struct EnumCaseParameter: Sendable {
    /// The label as it appears in source, including backtick escaping if present.
    let label: String?
    let type: String
}

func extractEnumCases(from enumDecl: EnumDeclSyntax) -> [EnumCase] {
    var cases: [EnumCase] = []

    for member in enumDecl.memberBlock.members {
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }

        for element in caseDecl.elements {
            // .text preserves backtick escaping — use directly, do NOT re-escape.
            let name = element.name.text
            var parameters: [EnumCaseParameter] = []

            if let parameterClause = element.parameterClause {
                for param in parameterClause.parameters {
                    let label = param.firstName?.text
                    parameters.append(EnumCaseParameter(
                        label: label,
                        type: param.type.trimmedDescription
                    ))
                }
            }

            cases.append(EnumCase(name: name, parameters: parameters))
        }
    }

    return cases
}

// MARK: - Enum → Dual<R> Struct + Infrastructure Expansion

func expandEnum(
    enumDecl: EnumDeclSyntax,
    node: AttributeSyntax,
    context: some MacroExpansionContext
) -> [DeclSyntax] {
    let cases = extractEnumCases(from: enumDecl)

    guard !cases.isEmpty else {
        context.diagnose(Diagnostic(
            node: node,
            message: DualDiagnostic.noEnumCases
        ))
        return []
    }

    let enumName = enumDecl.name.trimmedDescription
    let isPublic = isPublicDecl(enumDecl)
    let sendable = isSendable(enumDecl)
    let accessModifier = isPublic ? "public " : ""
    let inlinableAttr = isPublic ? "@inlinable\n    " : ""

    var members: [DeclSyntax] = []

    // 1. Dual<R> struct (Scott encoding)
    let sendableAnnotation = sendable ? "@Sendable " : ""

    var dualProperties: [String] = []
    var initParams: [String] = []

    for enumCase in cases {
        // case names from .text already include backtick escaping
        let name = enumCase.name

        if enumCase.parameters.isEmpty {
            dualProperties.append("\(accessModifier)var \(name): \(sendableAnnotation)() -> R")
            initParams.append("\(name): @escaping \(sendableAnnotation)() -> R")
        } else if enumCase.parameters.count == 1 {
            let param = enumCase.parameters[0]
            let paramPart = param.label != nil ? "_ \(param.label!): " : "_ arg: "
            dualProperties.append("\(accessModifier)var \(name): \(sendableAnnotation)(\(paramPart)\(param.type)) -> R")
            initParams.append("\(name): @escaping \(sendableAnnotation)(\(paramPart)\(param.type)) -> R")
        } else {
            let paramList = enumCase.parameters.map { param in
                let label = param.label ?? "_"
                return "_ \(label): \(param.type)"
            }.joined(separator: ", ")
            dualProperties.append("\(accessModifier)var \(name): \(sendableAnnotation)(\(paramList)) -> R")
            initParams.append("\(name): @escaping \(sendableAnnotation)(\(paramList)) -> R")
        }
    }

    let dualPropertiesStr = dualProperties.joined(separator: "\n        ")
    let initParamsStr = initParams.joined(separator: ",\n            ")
    let initAssignments = cases.map { c in
        "self.\(c.name) = \(c.name)"
    }.joined(separator: "\n            ")

    let dualStruct: DeclSyntax = """
        \(raw: accessModifier)struct Dual<R> {
            \(raw: dualPropertiesStr)

            \(raw: inlinableAttr)\(raw: accessModifier)init(
                \(raw: initParamsStr)
            ) {
                \(raw: initAssignments)
            }
        }
        """
    members.append(dualStruct)

    // 2. match function
    let matchCases = cases.map { enumCase in
        let name = enumCase.name

        if enumCase.parameters.isEmpty {
            return "case .\(name): dual.\(name)()"
        } else if enumCase.parameters.count == 1 {
            let param = enumCase.parameters[0]
            let binding = param.label != nil ? "let \(param.label!)" : "let v"
            let arg = param.label ?? "v"
            return "case .\(name)(\(binding)): dual.\(name)(\(arg))"
        } else {
            let bindings = enumCase.parameters.enumerated().map { i, param in
                param.label != nil ? "let \(param.label!)" : "let v\(i)"
            }.joined(separator: ", ")
            let args = enumCase.parameters.enumerated().map { i, param in
                param.label ?? "v\(i)"
            }.joined(separator: ", ")
            return "case .\(name)(\(bindings)): dual.\(name)(\(args))"
        }
    }.joined(separator: "\n            ")

    let matchFunc: DeclSyntax = """
        \(raw: inlinableAttr)\(raw: accessModifier)func match<R>(_ dual: Dual<R>) -> R {
            switch self {
            \(raw: matchCases)
            }
        }
        """
    members.append(matchFunc)

    // 3. Enum infrastructure (extraction, Case discriminant, Prisms, accessors)

    // Extraction properties — names already escaped from AST
    for enumCase in cases {
        members.append(generateExtractionProperty(
            caseName: enumCase.name,
            parameters: enumCase.parameters.map { ($0.label, $0.type) },
            isPublic: isPublic
        ))
    }

    // Case discriminant — names already escaped from AST
    let caseNames = cases.map(\.name)
    let caseDiscriminant: DeclSyntax = "\(raw: generateCaseDiscriminant(caseNames: caseNames, isPublic: isPublic))"
    members.append(caseDiscriminant)

    // var case: Case
    members.append(generateCaseProperty(
        caseNames: caseNames,
        isPublic: isPublic
    ))

    // Prisms struct
    members.append(generatePrismsStruct(
        cases: cases.map { ($0.name, $0.parameters.map { ($0.label, $0.type) }) },
        rootTypeName: enumName,
        isPublic: isPublic
    ))

    // Prism accessors
    members.append(contentsOf: generatePrismAccessors(
        rootTypeName: enumName,
        isPublic: isPublic
    ))

    return members
}
