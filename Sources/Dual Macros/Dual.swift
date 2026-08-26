@_exported public import Finite
@_exported public import Optic

@attached(member, names: arbitrary)
@attached(memberAttribute)
@attached(extension, conformances: Optic.__OpticPrismAccessible, names: arbitrary)
public macro Dual() =
    #externalMacro(
        module: "Dual_Macros_Implementation",
        type: "DualMacro"
    )
