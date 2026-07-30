// Co-Attachment Tests.swift
// swift-dual
//
// Negative fixture for the documented @Cases / @Dual co-attachment prohibition:
// attaching both macros to one declaration must diagnose on each attribute and
// expand to nothing.

import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Dual_Macros_Implementation

// MARK: - Macro registry

private let testMacros: [String: MacroSpec] = [
    "Cases": MacroSpec(type: CasesMacro.self),
    "Dual": MacroSpec(type: DualMacro.self),
]

// MARK: - Swift Testing adapter

/// Bridges `SwiftSyntaxMacrosGenericTestSupport.assertMacroExpansion`'s
/// framework-agnostic `failureHandler` callback to Swift Testing's
/// `Issue.record(...)`. Avoids `SwiftSyntaxMacrosTestSupport`, which
/// pulls XCTest (and transitively Foundation).
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

// MARK: - Suite hierarchy

extension CasesMacro {
    @Suite
    struct Test {
        @Suite struct `Edge Case` {}
    }
}

// MARK: - Negative co-attachment fixture

extension CasesMacro.Test.`Edge Case` {

    @Test
    func `attaching @Cases and @Dual to one enum diagnoses on both attributes and expands nothing`() {
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
