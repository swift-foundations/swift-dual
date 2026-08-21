public protocol CaseAnalyzable {
    associatedtype Cases
    static var cases: Cases { get }
}
