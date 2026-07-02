import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct DualMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        DualMacro.self
    ]
}
