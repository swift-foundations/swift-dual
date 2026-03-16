import SwiftSyntax
import SwiftSyntaxBuilder

/// Generates a `Case` discriminant enum conforming to `Finite.Enumerable`.
func generateCaseDiscriminant(
    caseNames: [String],
    isPublic: Bool
) -> String {
    let accessModifier = isPublic ? "public " : ""
    let inlinableAttr = isPublic ? "@inlinable\n        " : ""
    let caseCount = caseNames.count

    let caseCases = caseNames.map { "case \($0)" }.joined(separator: "\n            ")

    let caseOrdinalCases = caseNames.enumerated().map { index, name in
        "case .\(name): Ordinal_Primitives.Ordinal(\(index))"
    }.joined(separator: "\n                ")

    let uncheckedInitCases = caseNames.enumerated().map { index, name in
        if index == caseNames.count - 1 {
            "default: self = .\(name)"
        } else {
            "case \(index): self = .\(name)"
        }
    }.joined(separator: "\n                ")

    return """
        \(accessModifier)enum Case: Finite_Primitives.Finite.Enumerable, Sendable {
                \(caseCases)

                \(inlinableAttr)\(accessModifier)static var count: Cardinal_Primitives.Cardinal { Cardinal_Primitives.Cardinal(\(caseCount)) }

                \(inlinableAttr)\(accessModifier)var ordinal: Ordinal_Primitives.Ordinal {
                    switch self {
                    \(caseOrdinalCases)
                    }
                }

                \(inlinableAttr)\(accessModifier)init(__unchecked: Void, ordinal: Ordinal_Primitives.Ordinal) {
                    switch ordinal.rawValue {
                    \(uncheckedInitCases)
                    }
                }
            }
    """
}
