@_exported public import Case_Paths

@attached(member, names: arbitrary)
@attached(extension, conformances: Case_Paths.CaseAnalyzable, names: arbitrary)
public macro Cases() =
    #externalMacro(module: "Dual_Macros_Implementation", type: "CasesMacro")
