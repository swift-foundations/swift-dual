import Testing

@testable import Dual

@Suite
struct CasePathTests {

    @Test func `depth-1 is predicate`() {
        #expect(Screen.list.is(\.list) == true)
        #expect(Screen.list.is(\.home) == false)
        #expect(Screen.list.is(\.detail) == false)
        #expect(Screen.detail(3).is(\.detail) == true)
        #expect(Screen.edit(id: 1, draft: "d").is(\.edit) == true)
    }

    @Test func `depth-1 embed extract round-trip`() {

        let home = Screen.cases[keyPath: \.home]
        #expect(home.embed(()) == .home)
        #expect(home.extract(.home) != nil)
        #expect(home.extract(.list) == nil)

        let detail = Screen.cases[keyPath: \.detail]
        #expect(detail.embed(42) == .detail(42))
        #expect(detail.extract(.detail(42)) == 42)
        #expect(detail.extract(.home) == nil)

        let edit = Screen.cases[keyPath: \.edit]
        #expect(edit.embed((id: 9, draft: "x")) == .edit(id: 9, draft: "x"))
        let extracted = edit.extract(.edit(id: 9, draft: "x"))
        #expect(extracted?.id == 9)
        #expect(extracted?.draft == "x")
        #expect(edit.extract(.home) == nil)
    }

    @Test func `depth-3 composition round-trip`() {
        let creds = Credentials(token: "abc")

        let path = App.cases[keyPath: \.authenticate.api.credentials]

        let whole: App = path.embed(creds)
        #expect(whole == .authenticate(.api(.credentials(creds))))

        #expect(path.extract(whole) == creds)

        #expect(path.extract(.home) == nil)
        #expect(path.extract(.authenticate(.login)) == nil)
        #expect(path.extract(.authenticate(.api(.status))) == nil)
    }

    @Test func `depth-3 is predicate`() {
        let whole: App = .authenticate(.api(.credentials(Credentials(token: "x"))))
        #expect(whole.is(\.authenticate.api.credentials) == true)
        #expect(whole.is(\.authenticate.api.status) == false)
        #expect(whole.is(\.home) == false)

        #expect(whole.is(\.authenticate.api) == true)
        #expect(whole.is(\.authenticate) == true)
        #expect(App.authenticate(.login).is(\.authenticate.api) == false)
    }

    @Test func `nested @Cases inside a @Dual enum composes`() {

        let a = Outer.Inner.cases[keyPath: \.a]
        #expect(a.embed(5) == .a(5))
        #expect(a.extract(.a(5)) == 5)
        #expect(a.extract(.b) == nil)
        #expect(Outer.Inner.a(5).is(\.a) == true)
        #expect(Outer.Inner.b.is(\.a) == false)
    }

    @Test func `real @Dual and @Cases coexist in one target`() {

        #expect(Route.home.is(\.home) == true)
        #expect(Screen.home.is(\.home) == true)

        #expect(Outer.only.case == .only)
        _ = Outer.Inner.cases
    }
}
