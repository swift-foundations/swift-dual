import SwiftSyntax

func casesValueType(_ c: Case) -> String {
    if c.parameters.isEmpty { return "Void" }
    if c.parameters.count == 1 { return c.parameters[0].type }
    let tuple = c.parameters.map { p in
        p.label.map { "\($0): \(p.type)" } ?? p.type
    }.joined(separator: ", ")
    return "(\(tuple))"
}

func casesEmbedClosure(_ c: Case) -> String {
    if c.parameters.isEmpty { return "{ _ in .\(c.name) }" }
    if c.parameters.count == 1 {
        let label = c.parameters[0].label.map { "\($0): " } ?? ""
        return "{ .\(c.name)(\(label)$0) }"
    }
    let args = c.parameters.enumerated().map { i, p in
        (p.label.map { "\($0): " } ?? "") + "$0.\(i)"
    }.joined(separator: ", ")
    return "{ .\(c.name)(\(args)) }"
}

func casesExtractClosure(_ c: Case) -> String {
    if c.parameters.isEmpty {
        return "{ if case .\(c.name) = $0 { return () } else { return nil } }"
    }
    if c.parameters.count == 1 {
        let label = c.parameters[0].label.map { "\($0): " } ?? ""
        return "{ if case .\(c.name)(\(label)let v) = $0 { return v } else { return nil } }"
    }
    let patterns = c.parameters.enumerated().map { i, p in
        (p.label.map { "\($0): " } ?? "") + "let v\(i)"
    }.joined(separator: ", ")
    let tuple = c.parameters.enumerated().map { i, p in
        (p.label.map { "\($0): " } ?? "") + "v\(i)"
    }.joined(separator: ", ")
    return "{ if case .\(c.name)(\(patterns)) = $0 { return (\(tuple)) } else { return nil } }"
}

func generateCasesWitness(
    cases: [Case],
    root: String,
    isPublic: Bool
) -> [DeclSyntax] {
    let acc = isPublic ? "public " : ""

    let properties = cases.map { c in
        "\(acc)var \(c.name): Case_Paths.Case.Path<\(root), \(casesValueType(c))> { Case_Paths.Case.Path(embed: \(casesEmbedClosure(c)), extract: \(casesExtractClosure(c))) }"
    }.joined(separator: "\n        ")

    let witnessStruct: DeclSyntax = """
        \(raw: acc)struct Cases {
            \(raw: acc)init() {}
            \(raw: properties)
        }
        """

    let accessor: DeclSyntax = "\(raw: acc)static var cases: Cases { Cases() }"

    let isPredicate: DeclSyntax = """
        \(raw: acc)func `is`<Value>(_ keyPath: KeyPath<Cases, Case_Paths.Case.Path<\(raw: root), Value>>) -> Bool {
            Self.cases[keyPath: keyPath].extract(self) != nil
        }
        """

    return [witnessStruct, accessor, isPredicate]
}
