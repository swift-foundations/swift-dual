@_exported public import Case_Paths

/// Generates enum case-path addressing:
/// - a per-case witness `struct Cases` (one `Case.Path` property per case),
/// - a `static var cases: Cases` accessor,
/// - an `is(_:)` predicate keyed by a `Case.Path` keypath literal (`route.is(\.home)`),
/// - and a `CaseAnalyzable` conformance enabling depth composition of nested `@Cases` enums.
///
/// ```swift
/// @Cases enum Route {
///     case home
///     case detail(Int)
/// }
/// route.is(\.detail)                       // depth-1 predicate
/// Route.cases[keyPath: \.detail].embed(7)  // .detail(7)
/// ```
///
/// Depth composition works because `Case.Path` is `@dynamicMemberLookup`, so a keypath
/// literal can address a case several levels deep: `\.authenticate.api.credentials`.
///
/// `@Cases` and `@Dual` must not be attached to the *same* enum — a bare `is(_:)`
/// call would be ambiguous across the two generated witnesses. Same-package (and
/// nested) coexistence is clean; `@Cases` supersedes `@Dual`'s prism `is` surface.
@attached(member, names: arbitrary)
@attached(extension, conformances: Case_Paths.CaseAnalyzable, names: arbitrary)
public macro Cases() =
    #externalMacro(module: "Dual_Macros_Implementation", type: "CasesMacro")
