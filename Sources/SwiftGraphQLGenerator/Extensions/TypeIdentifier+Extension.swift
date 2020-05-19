import Meta

extension TypeIdentifier {
    
    static let decodable: TypeIdentifier = .init(name: "Decodable")
    static let encodable: TypeIdentifier = .init(name: "Encodable")
    static let codable: TypeIdentifier = .init(name: "Codable")
    static let equatable: TypeIdentifier = .init(name: "Equatable")
}
