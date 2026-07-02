import Testing

@testable import Dual

@Suite("Struct Dual")
struct StructDualTests {

    @Suite("Unit")
    struct Unit {

        // MARK: - Config (mixed types)

        @Test func configDualHostExtraction() {
            #expect(Config.Dual.host("x").host == "x")
        }

        @Test func configDualHostPortIsNil() {
            #expect(Config.Dual.host("x").port == nil)
        }

        @Test func configDualPortExtraction() {
            #expect(Config.Dual.port(80).port == 80)
        }

        @Test func configDualCaseOrdinals() {
            #expect(Config.Dual.Case.host.ordinal.rawValue == 0)
            #expect(Config.Dual.Case.port.ordinal.rawValue == 1)
        }

        @Test func configDualCaseCount() {
            #expect(Config.Dual.Case.count.rawValue == 2)
        }

        @Test func configDualCaseProperty() {
            #expect(Config.Dual.host("x").case == .host)
            #expect(Config.Dual.port(80).case == .port)
        }

        @Test func configDualPrismExtract() {
            #expect(Config.Dual.prisms.host.extract(.host("x")) == "x")
            #expect(Config.Dual.prisms.port.extract(.host("x")) == nil)
        }

        @Test func configDualIsMethod() {
            #expect(Config.Dual.host("x").is(\.host) == true)
            #expect(Config.Dual.host("x").is(\.port) == false)
        }

        @Test func configDualPrismSubscript() {
            #expect(Config.Dual.host("x")[prism: \.host] == "x")
            #expect(Config.Dual.host("x")[prism: \.port] == nil)
        }

        @Test func configDualModify() {
            var d = Config.Dual.host("old")
            d.modify(\.host) { $0 = "new" }
            #expect(d.host == "new")
        }

        // MARK: - Homogeneous (same-type subscript)

        @Test func homogeneousSubscriptGet() {
            let h = Homogeneous(x: 1, y: 2, z: 3)
            #expect(h[case: .x] == 1)
            #expect(h[case: .y] == 2)
            #expect(h[case: .z] == 3)
        }

        @Test func homogeneousSubscriptSet() {
            var h = Homogeneous(x: 1, y: 2, z: 3)
            h[case: .x] = 10
            #expect(h.x == 10)
            h[case: .y] = 20
            #expect(h.y == 20)
        }

        // MARK: - SingleField

        @Test func singleFieldDual() {
            let d = SingleField.Dual.value("hello")
            #expect(d.value == "hello")
            #expect(d.case == .value)
        }

        @Test func singleFieldHomogeneousSubscript() {
            var s = SingleField(value: "a")
            #expect(s[case: .value] == "a")
            s[case: .value] = "b"
            #expect(s.value == "b")
        }

        // MARK: - WithClosures

        @Test func withClosuresDualExists() {
            let d = WithClosures.Dual.total(42)
            #expect(d.total == 42)
        }
    }

    @Suite("Edge Cases")
    struct EdgeCase {

        // MARK: - StatuteArgs (space-containing identifiers)

        @Test func statuteArgsHomogeneousSubscript() {
            var args = StatuteArgs()
            args[case: .`condition one`] = true
            #expect(args.`condition one` == true)
            #expect(args[case: .`condition one`] == true)
        }

        @Test func statuteArgsCaseEnumeration() {
            var count = 0
            for _ in StatuteArgs.Dual.Case.allCases {
                count += 1
            }
            #expect(count == 3)
        }

        // MARK: - LetOnly (get-only subscript)

        @Test func letOnlySubscriptGetOnly() {
            let l = LetOnly(x: 5, y: 10)
            #expect(l[case: .x] == 5)
            #expect(l[case: .y] == 10)
        }
    }
}
