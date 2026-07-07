import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct DualMacrosPlugin: CompilerPlugin {
    // [any Macro.Type] element type is required by SwiftCompilerPlugin.CompilerPlugin.providingMacros.
    // swiftlint:disable:next no_any_protocol_existential
    let providingMacros: [any Macro.Type] = [
        DualMacro.self
    ]
}
