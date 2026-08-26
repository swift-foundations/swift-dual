import SwiftSyntax
import SwiftSyntaxBuilder

func generateCaseDiscriminant(
    caseNames: [String],
    isPublic: Bool
) -> String {
    let accessModifier = isPublic ? "public " : ""
    let inlinableAttr = isPublic ? "@inlinable\n        " : ""
    let caseCount = caseNames.count

    guard !caseNames.isEmpty else {

        return """
                \(accessModifier)enum Case: Finite.Finite.Enumerable, Sendable {

                        \(inlinableAttr)\(accessModifier)static var count: Cardinal.Cardinal { Cardinal.Cardinal(0) }

                        \(inlinableAttr)\(accessModifier)var ordinal: Ordinal.Ordinal {
                            switch self {}
                        }

                        \(inlinableAttr)\(accessModifier)init(_unchecked: Void, ordinal: Ordinal.Ordinal) {
                            fatalError("Case is uninhabited")
                        }
                    }
            """
    }

    let caseCases = caseNames.map { "case \($0)" }.joined(separator: "\n            ")

    let caseOrdinalCases = caseNames.enumerated().map { index, name in
        "case .\(name): Ordinal.Ordinal(\(index))"
    }.joined(separator: "\n                ")

    let uncheckedInitCases = caseNames.enumerated().map { index, name in
        if index == caseNames.count - 1 {
            "default: self = .\(name)"
        } else {
            "case \(index): self = .\(name)"
        }
    }.joined(separator: "\n                ")

    return """
            \(accessModifier)enum Case: Finite.Finite.Enumerable, Sendable {
                    \(caseCases)

                    \(inlinableAttr)\(accessModifier)static var count: Cardinal.Cardinal { Cardinal.Cardinal(\(caseCount)) }

                    \(inlinableAttr)\(accessModifier)var ordinal: Ordinal.Ordinal {
                        switch self {
                        \(caseOrdinalCases)
                        }
                    }

                    \(inlinableAttr)\(accessModifier)init(_unchecked: Void, ordinal: Ordinal.Ordinal) {
                        switch ordinal.rawValue {
                        \(uncheckedInitCases)
                        }
                    }
                }
        """
}
