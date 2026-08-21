@_exported public import Finite_Primitives
@_exported public import Optic_Primitives

@attached(member, names: arbitrary)
@attached(memberAttribute)
@attached(extension, conformances: Optic_Primitives.__OpticPrismAccessible, names: arbitrary)
public macro Dual() =
    #externalMacro(
        module: "Dual_Macros_Implementation",
        type: "DualMacro"
    )
