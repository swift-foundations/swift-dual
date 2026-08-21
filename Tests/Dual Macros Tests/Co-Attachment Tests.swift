import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Dual_Macros_Implementation

private let testMacros: [String: MacroSpec] = [
    "Cases": MacroSpec(type: CasesMacro.self),
    "Dual": MacroSpec(type: DualMacro.self),
]

private func expectMacroExpansion(
    _ originalSource: String,
    expandedSource: String,
    diagnostics: [DiagnosticSpec] = [],
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) {
    assertMacroExpansion(
        originalSource,
        expandedSource: expandedSource,
        diagnostics: diagnostics,
        macroSpecs: testMacros,
        failureHandler: { failure in
            Issue.record(
                Comment(rawValue: failure.message),
                sourceLocation: SourceLocation(
                    fileID: failure.location.fileID.description,
                    filePath: failure.location.filePath.description,
                    line: Int(failure.location.line),
                    column: Int(failure.location.column)
                )
            )
        },
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )
}

extension CasesMacro {
    @Suite
    struct Test {
        @Suite struct `Edge Case` {}
    }
}

extension CasesMacro.Test.`Edge Case` {

    @Test
    func `attaching @Cases and @Dual to one enum diagnoses on both attributes and expands nothing`()
    {
        expectMacroExpansion(
            """
            @Cases @Dual
            enum Route {
                case home
                case detail(Int)
            }
            """,
            expandedSource: """
                enum Route {
                    case home
                    case detail(Int)
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Cases and @Dual must not be attached to the same declaration",
                    line: 1,
                    column: 1,
                    severity: .error
                ),
                DiagnosticSpec(
                    message: "@Dual and @Cases must not be attached to the same declaration",
                    line: 1,
                    column: 8,
                    severity: .error
                ),
            ]
        )
    }
}
