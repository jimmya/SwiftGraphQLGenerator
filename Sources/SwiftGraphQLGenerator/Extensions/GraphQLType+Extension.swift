import GraphQL

public extension GraphQL.`Type` {
    
    /// Unwrap Type until there is no more nesting. Last type should be a named type.
    func toArray() -> [GraphQL.`Type`] {
        var types: [GraphQL.`Type`?] = []
        var currentType: GraphQL.`Type`? = self
        repeat {
            types.append(currentType)
            if let nonNull = currentType as? NonNullType {
                currentType = nonNull.type
            } else if let list = currentType as? ListType {
                currentType = list.type
            } else {
                currentType = nil
            }
        } while currentType != nil
        return types.compactMap { $0 }
    }
}
