import SwiftSyntax
import SwiftSyntaxBuilder

/// Common representation for a prism case, used by both struct Dual and enum prism generation.
struct PrismCase {
    let caseName: String
    let rootTypeName: String
    let parameters: [(label: String?, type: String)]
}

/// Generates a single prism property for a case.
func generatePrism(for prismCase: PrismCase) -> String {
    let name = prismCase.caseName
    let root = prismCase.rootTypeName

    if prismCase.parameters.isEmpty {
        return """
        public var \(name): Optic_Primitives.Optic.Prism<\(root), Void> {
                    Optic_Primitives.Optic.Prism(
                        embed: { _ in .\(name) },
                        extract: { if case .\(name) = $0 { return () } else { return nil } }
                    )
                }
        """
    } else if prismCase.parameters.count == 1 {
        let param = prismCase.parameters[0]
        let paramType = param.type
        let embedArg = param.label != nil ? "\(param.label!): $0" : "$0"
        let extractPattern = param.label != nil ? "\(param.label!): let v" : "let v"

        return """
        public var \(name): Optic_Primitives.Optic.Prism<\(root), \(paramType)> {
                    Optic_Primitives.Optic.Prism(
                        embed: { .\(name)(\(embedArg)) },
                        extract: { if case .\(name)(\(extractPattern)) = $0 { return v } else { return nil } }
                    )
                }
        """
    } else {
        let tupleTypes = prismCase.parameters.map { p in
            p.label != nil ? "\(p.label!): \(p.type)" : p.type
        }.joined(separator: ", ")

        let embedArgs = prismCase.parameters.enumerated().map { i, p in
            p.label != nil ? "\(p.label!): $0.\(i)" : "$0.\(i)"
        }.joined(separator: ", ")

        let extractPatterns = prismCase.parameters.enumerated().map { i, p in
            p.label != nil ? "\(p.label!): let v\(i)" : "let v\(i)"
        }.joined(separator: ", ")

        let extractTuple = prismCase.parameters.enumerated().map { i, p in
            p.label != nil ? "\(p.label!): v\(i)" : "v\(i)"
        }.joined(separator: ", ")

        return """
        public var \(name): Optic_Primitives.Optic.Prism<\(root), (\(tupleTypes))> {
                    Optic_Primitives.Optic.Prism(
                        embed: { .\(name)(\(embedArgs)) },
                        extract: { if case .\(name)(\(extractPatterns)) = $0 { return (\(extractTuple)) } else { return nil } }
                    )
                }
        """
    }
}
