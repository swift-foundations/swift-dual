# swift-dual

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Computes the categorical dual of a Swift type: `@Dual` generates the coproduct of a struct (one enum case per stored property) and the product of an enum (one handler per case, with a `match` function for exhaustive case analysis).

## Quick Start

The dual of an enum is a product of case handlers — case analysis becomes a first-class value you can store, pass, and reuse, which `switch` statements cannot do:

```swift
import Dual

@Dual
enum Route: Sendable {
    case home
    case profile(id: Int)
    case settings
}

// Exhaustive case analysis as a value (Scott encoding).
// Adding a Route case breaks this initializer at compile time.
let describe = Route.Dual<String>(
    home: { "Home" },
    profile: { id in "Profile \(id)" },
    settings: { "Settings" }
)

Route.profile(id: 42).match(describe)   // "Profile 42"

// Generated case accessors, prisms, and typed discriminants:
Route.profile(id: 42).profile           // Optional(42)
Route.home.is(\.home)                   // true
Route.prisms.profile.extract(.home)     // nil
Route.Case.profile.ordinal.rawValue     // 1
Route.Case.count.rawValue               // 3
```

The dual of a struct is a coproduct — a generated enum with one case per stored property, preserving each field's literal type:

```swift
import Dual

@Dual
struct Config: Sendable {
    var host: String
    var port: Int
}

let field: Config.Dual = .host("localhost")
field.host                     // Optional("localhost")
field.case                     // .host
Config.Dual.Case.allCases      // [.host, .port]
Config.Dual.prisms.host.extract(.host("localhost"))  // "localhost"
```

When every stored property shares one type, the struct additionally gains a keyed subscript over its own fields:

```swift
import Dual

@Dual
struct Point: Sendable {
    var x: Int
    var y: Int
    var z: Int
}

var point = Point(x: 1, y: 2, z: 3)
point[case: .y]        // 2
point[case: .y] = 20   // read-write for var fields; get-only when fields are let
```

## Installation

Add swift-dual to your Package.swift (no tags are published yet; pin to `main`):

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-dual.git", branch: "main")
]
```

Add the product to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Dual", package: "swift-dual")
    ]
)
```

### Requirements

- Swift 6.3+
- macOS 26+, iOS 26+, tvOS 26+, watchOS 26+, visionOS 26+

## Key Features

- **Struct → coproduct** — a nested `Dual` enum with one case per stored property, preserving literal field types (including closure fields)
- **Enum → product** — a nested `Dual<R>` handler struct (Scott encoding) plus a `match` function; handler initializers are exhaustive, so adding a case is a compile-time break at every match site
- **Prisms on every dual** — a generated `prisms` catalog with `extract`, plus `is(_:)`, `subscript[prism:]`, and in-place `modify(_:_:)` for each case
- **Typed case discriminants** — a generated `Case` enum with typed `ordinal` and `count` values rather than raw integers
- **Homogeneous field subscript** — structs whose fields share one type gain `subscript[case:]` (read-write for `var`, get-only for `let`)
- **Keyword and raw identifiers** — members named `default`, `return`, or backticked identifiers containing spaces expand correctly

## Architecture

| Product | When to import |
|---------|----------------|
| `Dual` | The `@Dual` macro plus re-exported prism and discriminant types — the normal choice |
| `Dual Test Support` | Test targets; currently re-exports `Dual` and reserves space for future test utilities |

The macro expansion itself lives in an implementation-only target (`Dual Macros Implementation`, built on swift-syntax) that consumers never import directly.

## Related Packages

### Dependencies

- [swift-optic-primitives](https://github.com/swift-primitives/swift-optic-primitives) — Prism types backing the generated case accessors; re-exported by `Dual` (pre-release, pin `branch: "main"`).
- [swift-finite-primitives](https://github.com/swift-primitives/swift-finite-primitives) — Typed `ordinal` / `count` discriminants; re-exported by `Dual` (pre-release, pin `branch: "main"`).

### Third-Party Dependencies

- [swift-syntax](https://github.com/swiftlang/swift-syntax) — Macro implementation.

## Community

<!-- BEGIN: discussion -->
*Discussion thread will be created at first public flip.*
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE](LICENSE.md).
