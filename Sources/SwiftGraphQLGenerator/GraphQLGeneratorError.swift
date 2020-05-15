import Foundation

enum GraphQLGeneratorError: Error {
    case schemaNotRead
    case noQueryName
    case invalidSelectionType
    case namelessType
    case unexpectedType
    case unionWithoutTypename
}
