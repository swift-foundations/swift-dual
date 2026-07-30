import Testing

@testable import Dual

@Suite
struct CasePathTests {

    // MARK: Part 1 — `.is(\.case)` keypath-literal shape (depth-1)

    @Test func `depth-1 is predicate`() {
        #expect(Screen.list.is(\.list) == true)
        #expect(Screen.list.is(\.home) == false)
        #expect(Screen.list.is(\.detail) == false)
        #expect(Screen.detail(3).is(\.detail) == true)
        #expect(Screen.edit(id: 1, draft: "d").is(\.edit) == true)
    }

    @Test func `depth-1 embed extract round-trip`() {
        // No-payload case.
        let home = Screen.cases[keyPath: \.home]
        #expect(home.embed(()) == .home)
        #expect(home.extract(.home) != nil)
        #expect(home.extract(.list) == nil)

        // Single-payload case.
        let detail = Screen.cases[keyPath: \.detail]
        #expect(detail.embed(42) == .detail(42))
        #expect(detail.extract(.detail(42)) == 42)
        #expect(detail.extract(.home) == nil)

        // Multi-payload (tuple) case.
        let edit = Screen.cases[keyPath: \.edit]
        #expect(edit.embed((id: 9, draft: "x")) == .edit(id: 9, draft: "x"))
        let extracted = edit.extract(.edit(id: 9, draft: "x"))
        #expect(extracted?.id == 9)
        #expect(extracted?.draft == "x")
        #expect(edit.extract(.home) == nil)
    }

    // MARK: Part 2 — depth-3 @dynamicMemberLookup composition (acceptance shape)

    @Test func `depth-3 composition round-trip`() {
        let creds = Credentials(token: "abc")
        // Composed keypath literal: KeyPath<App.Cases, Case.Path<App, Credentials>>.
        let path = App.cases[keyPath: \.authenticate.api.credentials]

        let whole: App = path.embed(creds)
        #expect(whole == .authenticate(.api(.credentials(creds))))

        #expect(path.extract(whole) == creds)
        // Negative extractions all return nil.
        #expect(path.extract(.home) == nil)
        #expect(path.extract(.authenticate(.login)) == nil)
        #expect(path.extract(.authenticate(.api(.status))) == nil)
    }

    @Test func `depth-3 is predicate`() {
        let whole: App = .authenticate(.api(.credentials(Credentials(token: "x"))))
        #expect(whole.is(\.authenticate.api.credentials) == true)
        #expect(whole.is(\.authenticate.api.status) == false)
        #expect(whole.is(\.home) == false)

        // Intermediate depth-2 / depth-1 hops compose too.
        #expect(whole.is(\.authenticate.api) == true)
        #expect(whole.is(\.authenticate) == true)
        #expect(App.authenticate(.login).is(\.authenticate.api) == false)
    }

    // MARK: Part 3 — coexistence with the real @Dual

    @Test func `nested @Cases inside a @Dual enum composes`() {
        // Compiles only because @Cases codegen fully-qualifies `Case_Paths.Case.Path`
        // (inside `Outer`, an unqualified `Case` binds to the @Dual discriminant).
        let a = Outer.Inner.cases[keyPath: \.a]
        #expect(a.embed(5) == .a(5))
        #expect(a.extract(.a(5)) == 5)
        #expect(a.extract(.b) == nil)
        #expect(Outer.Inner.a(5).is(\.a) == true)
        #expect(Outer.Inner.b.is(\.a) == false)
    }

    @Test func `real @Dual and @Cases coexist in one target`() {
        // `Route` is @Dual (Test Fixtures.swift); `Screen` is @Cases — both build & run here.
        #expect(Route.home.is(\.home) == true)  // @Dual prism `is`
        #expect(Screen.home.is(\.home) == true)  // @Cases case-path `is`
        // The @Dual discriminant and the @Cases witness are both present, no collision.
        #expect(Outer.only.case == .only)
        _ = Outer.Inner.cases
    }
}
