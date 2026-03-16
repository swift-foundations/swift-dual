@_exported public import Optic_Primitives
@_exported public import Finite_Primitives

/// Computes the categorical dual of a type.
///
/// On a struct (product type), generates a nested `Dual` enum (coproduct)
/// with one case per stored property, preserving literal field types.
///
/// On an enum (coproduct), generates a nested `Dual<R>` struct (product)
/// with one handler closure per case (Scott encoding), plus a `match`
/// function for case analysis.
///
/// ```swift
/// @Dual struct Config: Sendable {
///     var host: String
///     var port: Int
/// }
/// // Config.Dual.host("localhost")
/// // Config.Dual.Case.allCases
///
/// @Dual enum Route: Sendable {
///     case home
///     case profile(id: Int)
/// }
/// // route.match(Route.Dual(home: { "Home" }, profile: { id in "Profile \(id)" }))
/// ```
@attached(member, names: arbitrary)
@attached(memberAttribute)
@attached(extension, conformances: Optic_Primitives.__OpticPrismAccessible, names: arbitrary)
public macro Dual() = #externalMacro(
    module: "Dual_Macros_Implementation",
    type: "DualMacro"
)
