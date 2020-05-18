//
// Generated by SWiftGraphQLGenerator
// DO NOT MODIFY!
//

import Foundation

public struct HumanFragment: Decodable, Equatable {

    public let name: String
    public let friends: Optional<Array<Optional<Character>>>
    public let appearsIn: Array<Optional<Episode>>

    public enum CodingKeys: String, CodingKey {
        case name
        case friends
        case appearsIn
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: CodingKeys.name)
        friends = try values.decodeIfPresent(Array<Optional<Character>>.self, forKey: CodingKeys.friends)
        appearsIn = try values.decode(Array<Optional<Episode>>.self, forKey: CodingKeys.appearsIn)
    }

    public struct Character: Decodable, Equatable {

        public let name: String
        public let asDroid: Optional<Droid>
        public let asHuman1: Optional<Human1>
        public let asHuman2: Optional<Human2>

        public enum CodingKeys: String, CodingKey {
            case __typename
            case name
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            name = try values.decode(String.self, forKey: CodingKeys.name)
            let type = try values.decode(String.self, forKey: .__typename)
            switch type {
            case "Droid":
                asDroid = try? Droid(from: decoder)
                asHuman1 = nil
                asHuman2 = nil
            case "Human":
                asDroid = nil
                asHuman1 = try? Human1(from: decoder)
                asHuman2 = try? Human2(from: decoder)
            default:
                asDroid = nil
                asHuman1 = nil
                asHuman2 = nil
            }
        }

        public struct Droid: Decodable, Equatable {

            public let primaryFunction: Optional<String>

            public enum CodingKeys: String, CodingKey {
                case primaryFunction
            }

            public init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                primaryFunction = try values.decodeIfPresent(String.self, forKey: CodingKeys.primaryFunction)
            }
        }

        public struct Human1: Decodable, Equatable {

            public let mass: Optional<Double>

            public enum CodingKeys: String, CodingKey {
                case mass
            }

            public init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                mass = try values.decodeIfPresent(Double.self, forKey: CodingKeys.mass)
            }
        }

        public struct Human2: Decodable, Equatable {

            public let homePlanet: Optional<String>

            public enum CodingKeys: String, CodingKey {
                case homePlanet
            }

            public init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                homePlanet = try values.decodeIfPresent(String.self, forKey: CodingKeys.homePlanet)
            }
        }
    }
}

public struct CreateReview: Codable, Equatable {

    public let stars: Int

    public struct Data: Decodable, Equatable {

        public let createReview: Optional<Review>

        public struct Review: Decodable, Equatable {

            public let stars: Int

            public enum CodingKeys: String, CodingKey {
                case stars
            }

            public init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                stars = try values.decode(Int.self, forKey: CodingKeys.stars)
            }
        }
    }
}

public struct Search: Codable, Equatable {

    public struct Data: Decodable, Equatable {

        public let search: Optional<Array<Optional<SearchResult>>>

        public enum SearchResult: Decodable, Equatable {

            case droid(droid: Droid)
            case human(human: Human)
            case starship(starship: Starship)

            enum ItemType: String, Decodable {
                case droid = "Droid"
                case human = "Human"
                case starship = "Starship"
            }

            enum ItemTypeKey: String, CodingKey {
                case typeName = "__typename"
            }

            public init(from decoder: Decoder) throws {
                let typeValues = try decoder.container(keyedBy: ItemTypeKey.self)
                let type = try typeValues.decode(ItemType.self, forKey: .typeName)
                switch type {
                case .droid:
                    self = .droid(droid: try Droid(from: decoder))
                case .human:
                    self = .human(human: try Human(from: decoder))
                case .starship:
                    self = .starship(starship: try Starship(from: decoder))
                }
            }

            public struct Droid: Decodable, Equatable {

                public let name: String

                public enum CodingKeys: String, CodingKey {
                    case name
                }

                public init(from decoder: Decoder) throws {
                    let values = try decoder.container(keyedBy: CodingKeys.self)
                    name = try values.decode(String.self, forKey: CodingKeys.name)
                }
            }

            public struct Human: Decodable, Equatable {

                public let humanFragment: HumanFragment

                public enum CodingKeys: String, CodingKey {
                    case humanFragment
                }

                public init(from decoder: Decoder) throws { humanFragment = try HumanFragment(from: decoder) }
            }

            public struct Starship: Decodable, Equatable {
            }
        }
    }
}

public enum Episode: String, Decodable, Equatable {
    case EMPIRE
    case JEDI
    case NEWHOPE
}
