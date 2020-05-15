import Foundation

public struct GraphQLResponse<T: Decodable>: Decodable {

    public let data: T
}
