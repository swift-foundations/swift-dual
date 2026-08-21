public import Dual
import Testing

@Dual
struct Config: Sendable {
    var host: String
    var port: Int
}

@Dual
struct Homogeneous: Sendable {
    var x: Int
    var y: Int
    var z: Int
}

@Dual
struct StatuteArgs: Sendable {
    var `condition one`: Bool? = nil
    var `condition two`: Bool? = nil
    var `condition three`: Bool? = nil
}

@Dual
struct SingleField: Sendable {
    var value: String
}

@Dual
struct LetOnly: Sendable {
    let x: Int
    let y: Int
}

@Dual
struct WithClosures: Sendable {
    var fetch: @Sendable (Int) -> String
    var total: Int
}

@Dual
struct Empty: Sendable {}

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
