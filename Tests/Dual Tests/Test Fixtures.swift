import Testing
public import Dual

// MARK: - Struct Fixtures

/// Mixed types — no homogeneous subscript.
@Dual
struct Config: Sendable {
    var host: String
    var port: Int
}

/// Same type — homogeneous subscript generated.
@Dual
struct Homogeneous: Sendable {
    var x: Int
    var y: Int
    var z: Int
}

/// Bool? pattern (statute encoding use case) with space-containing identifiers.
@Dual
struct StatuteArgs: Sendable {
    var `condition one`: Bool? = nil
    var `condition two`: Bool? = nil
    var `condition three`: Bool? = nil
}

/// Single field.
@Dual
struct SingleField: Sendable {
    var value: String
}

/// Let-only — get-only subscript.
@Dual
struct LetOnly: Sendable {
    let x: Int
    let y: Int
}

/// Closure fields — pure structural dual preserves literal closure types.
@Dual
struct WithClosures: Sendable {
    var fetch: @Sendable (Int) -> String
    var total: Int
}

/// Empty struct — dual is an uninhabited enum (unit → void).
@Dual
struct Empty: Sendable {}

// MARK: - Enum Fixtures

@Dual
enum Route: Sendable {
    case home
    case profile(id: Int)
    case settings
}

@Dual
enum Action: Sendable {
    case load
    case save(path: String)
    case transform(input: Int, scale: Double)
}

@Dual
enum KeywordCases: Sendable {
    case `default`
    case `return`(value: String)
}
