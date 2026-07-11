/// The witness protocol a `@Cases` enum conforms to (macro-generated) so that
/// `Case.Path` composition can reach a nested enum's own `Cases` witness during a
/// depth lookup.
///
/// `associatedtype Cases` is satisfied by the generated nested `Cases` struct;
/// `static var cases` by the generated accessor.
public protocol CaseAnalyzable {
    associatedtype Cases
    static var cases: Cases { get }
}
