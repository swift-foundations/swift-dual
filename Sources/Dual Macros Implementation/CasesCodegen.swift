import SwiftSyntax

// MARK: - @Cases per-case codegen
//
// Reuses the `Case` model + `extractCases` / `isPublicDecl` from EnumExpansion.swift /
// Utilities.swift. Every generated reference to the runtime value type is emitted
// FULLY-QUALIFIED as `Case_Paths.Case.Path` — inside a @Dual enum's scope the
// generated nested `Case` discriminant shadows the top-level `Case` namespace.

/// The `Value` type carried by a case's `Case.Path<Root, Value>`.
func casesValueType(_ c: Case) -> String {
    if c.parameters.isEmpty { return "Void" }
    if c.parameters.count == 1 { return c.parameters[0].type }
    let tuple = c.parameters.map { p in
        p.label.map { "\($0): \(p.type)" } ?? p.type
    }.joined(separator: ", ")
    return "(\(tuple))"
}

/// `embed: (Value) -> Root` closure source for a case.
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

/// `extract: (Root) -> Value?` closure source for a case.
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

/// Members installed inside a `@Cases` enum: the `Cases` witness (one `Case.Path`
/// property per case), a `static var cases` accessor, and an `is(_:)` predicate keyed
/// by a `KeyPath<Cases, Case_Paths.Case.Path<Root, Value>>`.
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
