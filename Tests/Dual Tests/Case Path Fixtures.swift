public import Dual

// MARK: - @Cases fixtures
//
// Subject enums for @Cases: a flat enum (mixed payloads), a 3-level nested chain
// (depth-3 composition `\.authenticate.api.credentials` — the identities-types
// deepest-chain acceptance shape), and coexistence with the REAL @Dual.

// MARK: Flat enum — 3+ cases, mixed payload / no-payload

@Cases
public enum Screen: Equatable {
    case home
    case list
    case detail(Int)
    case edit(id: Int, draft: String)
}

// MARK: 3-level nested chain — reproduces `\.authenticate.api.credentials`

@Cases
public enum App: Equatable {
    case home
    case authenticate(Auth)
}

@Cases
public enum Auth: Equatable {
    case login
    case api(Api)
}

@Cases
public enum Api: Equatable {
    case status
    case credentials(Credentials)
}

public struct Credentials: Equatable {
    public let token: String
    public init(token: String) { self.token = token }
}

// MARK: Coexistence with the REAL @Dual (its generated nested `Case` discriminant in scope)
//
// `Outer` is @Dual, so it generates a nested `enum Case` discriminant. `Inner` is a
// @Cases enum nested inside `Outer` — inside `Outer.Inner` the unqualified name `Case`
// resolves to `Outer.Case` (the discriminant), NOT the runtime namespace. This fixture
// compiles ONLY because @Cases codegen emits fully-qualified `Case_Paths.Case.Path`.
// (This is exactly the shadowing the spike's @DualLike stand-in did not reproduce.)

@Dual
public enum Outer: Sendable {
    case only

    @Cases
    public enum Inner: Equatable {
        case a(Int)
        case b
    }
}
