/// Namespace for enum case-path addressing.
///
/// `Case.Path<Root, Value>` (declared in `Case.Path.swift`) carries an embed/extract
/// pair addressing one case of an enum. `@Cases` generates keypath-addressable
/// `Case.Path` values per case; because `Case.Path` is `@dynamicMemberLookup`, nested
/// `@Cases` enums compose to arbitrary depth (`\.a.b.c`).
///
/// Generated code references this fully-qualified (`Case_Paths.Case.Path`): inside a
/// `@Dual`-annotated enum's scope the compiler-generated nested `Case` discriminant
/// shadows this top-level namespace.
public enum Case {}
