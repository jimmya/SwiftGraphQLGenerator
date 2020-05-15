import Foundation
import Meta

public enum Primitives: String {
    
    case ID
    case Int
    case Float
    case String
    case Boolean
    
    public var type: TypeIdentifierName {
        switch self {
            case .ID: return .string
            case .Int: return .int
            case .Float: return .double
            case .String: return .string
            case .Boolean: return .bool
        }
    }
}
