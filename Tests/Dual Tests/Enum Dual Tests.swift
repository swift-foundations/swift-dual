import Testing

@testable import Dual

@Suite("Enum Dual")
struct EnumDualTests {

    @Suite("Unit")
    struct Unit {

        // MARK: - Route

        @Test func routeMatchDispatches() {
            let describe = Route.Dual<String>(
                home: { "Home" },
                profile: { id in "Profile \(id)" },
                settings: { "Settings" }
            )
            #expect(Route.home.match(describe) == "Home")
            #expect(Route.profile(id: 42).match(describe) == "Profile 42")
            #expect(Route.settings.match(describe) == "Settings")
        }

        @Test func routeExtraction() {
            #expect(Route.home.home != nil)
            #expect(Route.home.profile == nil)
            #expect(Route.profile(id: 42).profile == 42)
        }

        @Test func routeCaseDiscriminant() {
            #expect(Route.Case.home.ordinal.rawValue == 0)
            #expect(Route.Case.profile.ordinal.rawValue == 1)
            #expect(Route.Case.settings.ordinal.rawValue == 2)
            #expect(Route.Case.count.rawValue == 3)
        }

        @Test func routeCaseProperty() {
            #expect(Route.home.case == .home)
            #expect(Route.profile(id: 1).case == .profile)
            #expect(Route.settings.case == .settings)
        }

        @Test func routePrisms() {
            #expect(Route.prisms.home.extract(.home) != nil)
            #expect(Route.prisms.profile.extract(.profile(id: 42)) == 42)
            #expect(Route.prisms.profile.extract(.home) == nil)
        }

        @Test func routeIsMethod() {
            #expect(Route.home.is(\.home) == true)
            #expect(Route.home.is(\.profile) == false)
        }

        @Test func routePrismSubscript() {
            #expect(Route.profile(id: 42)[prism: \.profile] == 42)
            #expect(Route.home[prism: \.profile] == nil)
        }

        @Test func routeModify() {
            var r = Route.profile(id: 1)
            r.modify(\.profile) { $0 = 99 }
            #expect(r.profile == 99)
        }

        // MARK: - Action (multi-param)

        @Test func actionTransformExtraction() {
            let t = Action.transform(input: 1, scale: 2.0).transform
            #expect(t?.input == 1)
            #expect(t?.scale == 2.0)
        }

        @Test func actionMatch() {
            let handler = Action.Dual<String>(
                load: { "Loading" },
                save: { path in "Saving \(path)" },
                transform: { input, scale in "Transform \(input) x\(scale)" }
            )
            #expect(Action.load.match(handler) == "Loading")
            #expect(Action.save(path: "/tmp").match(handler) == "Saving /tmp")
            #expect(Action.transform(input: 1, scale: 2.0).match(handler) == "Transform 1 x2.0")
        }
    }

    @Suite("Edge Cases")
    struct EdgeCase {

        // MARK: - KeywordCases

        @Test func keywordCasesCompileAndMatch() {
            let handler = KeywordCases.Dual<String>(
                default: { "Default" },
                return: { value in "Return \(value)" }
            )
            #expect(KeywordCases.default.match(handler) == "Default")
            #expect(KeywordCases.return(value: "ok").match(handler) == "Return ok")
        }

        @Test func keywordCasesExtraction() {
            #expect(KeywordCases.default.`default` != nil)
            #expect(KeywordCases.default.`return` == nil)
            #expect(KeywordCases.return(value: "x").`return` == "x")
        }
    }
}
