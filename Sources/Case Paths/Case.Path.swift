extension Case {
    /// A case-path: an embed/extract pair addressing one case of `Root` that carries `Value`.
    ///
    /// `@dynamicMemberLookup` (SE-0252) with a `KeyPath`-based subscript is what makes depth
    /// composition `\.a.b.c` type-check: each hop past the first is a dynamic-member lookup
    /// that composes embed/extract, requiring the hop's `Value` to itself be `CaseAnalyzable`
    /// (so its generated `Cases` witness is reachable).
    ///
    /// This is the value held at each keypath position: `KeyPath<Enum.Cases, Case.Path<Enum, Value>>`.
    @dynamicMemberLookup
    public struct Path<Root, Value> {
        public let embed: (Value) -> Root
        public let extract: (Root) -> Value?

        public init(embed: @escaping (Value) -> Root, extract: @escaping (Root) -> Value?) {
            self.embed = embed
            self.extract = extract
        }

        /// Depth composition: appending `.child` to a `Case.Path<Root, Value>` where
        /// `Value: CaseAnalyzable` yields `Case.Path<Root, Sub>` by threading embed/extract.
        public subscript<Sub>(
            dynamicMember keyPath: KeyPath<Value.Cases, Case.Path<Value, Sub>>
        ) -> Case.Path<Root, Sub> where Value: CaseAnalyzable {
            let inner = Value.cases[keyPath: keyPath]
            return Case.Path<Root, Sub>(
                embed: { sub in embed(inner.embed(sub)) },
                extract: { root in extract(root).flatMap(inner.extract) }
            )
        }
    }
}
