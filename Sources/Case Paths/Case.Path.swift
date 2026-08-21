extension Case {

    @dynamicMemberLookup
    public struct Path<Root, Value> {
        public let embed: (Value) -> Root
        public let extract: (Root) -> Value?

        public init(embed: @escaping (Value) -> Root, extract: @escaping (Root) -> Value?) {
            self.embed = embed
            self.extract = extract
        }

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
