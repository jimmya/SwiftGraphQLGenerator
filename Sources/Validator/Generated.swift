//
// Generated by SWiftGraphQLGenerator
// DO NOT MODIFY!
//

import Foundation

public struct HumanFragment: Decodable, Equatable {

    static let definition =  
    """
    fragment HumanFragment on Human {
      name
      friends {
        __typename
        name
        ... on Human {
          mass
        }
        ... on Human {
          ...HumanFragment2
        }
        ... on Droid {
          ...DroidFragment
        }
      }
      appearsIn
    }
    """

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

            public let droidFragment: DroidFragment

            public enum CodingKeys: String, CodingKey {
                case droidFragment
            }

            public init(from decoder: Decoder) throws { droidFragment = try DroidFragment(from: decoder) }
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

            public let humanFragment2: HumanFragment2

            public enum CodingKeys: String, CodingKey {
                case humanFragment2
            }

            public init(from decoder: Decoder) throws { humanFragment2 = try HumanFragment2(from: decoder) }
        }
    }
}

public struct HumanFragment2: Decodable, Equatable {

    static let definition =  
    """
    fragment HumanFragment2 on Human {
      name
      friends {
        __typename
        name
        ... on Human {
          ...HumanFragment3
        }
      }
    }
    """

    public let name: String
    public let friends: Optional<Array<Optional<Character>>>

    public enum CodingKeys: String, CodingKey {
        case name
        case friends
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: CodingKeys.name)
        friends = try values.decodeIfPresent(Array<Optional<Character>>.self, forKey: CodingKeys.friends)
    }

    public struct Character: Decodable, Equatable {

        public let name: String
        public let asHuman: Optional<Human>

        public enum CodingKeys: String, CodingKey {
            case __typename
            case name
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            name = try values.decode(String.self, forKey: CodingKeys.name)
            let type = try values.decode(String.self, forKey: .__typename)
            switch type {
            case "Human":
                asHuman = try? Human(from: decoder)
            default:
                asHuman = nil
            }
        }

        public struct Human: Decodable, Equatable {

            public let humanFragment3: HumanFragment3

            public enum CodingKeys: String, CodingKey {
                case humanFragment3
            }

            public init(from decoder: Decoder) throws { humanFragment3 = try HumanFragment3(from: decoder) }
        }
    }
}

public struct HumanFragment3: Decodable, Equatable {

    static let definition =  
    """
    fragment HumanFragment3 on Human {
      name
    }
    """

    public let name: String

    public enum CodingKeys: String, CodingKey {
        case name
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: CodingKeys.name)
    }
}

public struct DroidFragment: Decodable, Equatable {

    static let definition =  
    """
    fragment DroidFragment on Droid {
      primaryFunction
    }
    """

    public let primaryFunction: Optional<String>

    public enum CodingKeys: String, CodingKey {
        case primaryFunction
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        primaryFunction = try values.decodeIfPresent(String.self, forKey: CodingKeys.primaryFunction)
    }
}

public struct StarshipFragment: Decodable, Equatable {

    static let definition =  
    """
    fragment StarshipFragment on Starship {
      length
    }
    """

    public let length: Optional<Double>

    public enum CodingKeys: String, CodingKey {
        case length
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        length = try values.decodeIfPresent(Double.self, forKey: CodingKeys.length)
    }
}

public struct CreateReview: Encodable, Equatable {

    static let definition =  
    """
    mutation CreateReview($stars: Int!) {
      createReview(episode: NEWHOPE, review: { stars: $stars }) {
        stars
      }
    }
    """

    public let query = Self.definition
    public let operationName = "CreateReview"
    public let variables: Variables

    public init(variables: Variables) { self.variables = variables }

    public struct Variables: Encodable, Equatable {

        public let stars: Int

        public init(stars: Int) { self.stars = stars }
    }

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

public struct Search: Encodable, Equatable {

    static let definition =  
    """
    query Search($query: String!) {
      search(text: $query) {
        __typename
        ... on Human {
          ... HumanFragment
        }
        ... on Droid {
          ... DroidFragment
        }
      }
    }
    """ + DroidFragment.definition + HumanFragment.definition + HumanFragment2.definition + HumanFragment3.definition

    public let query = Self.definition
    public let operationName = "Search"
    public let variables: Variables

    public init(variables: Variables) { self.variables = variables }

    public struct Variables: Encodable, Equatable {

        public let query: String

        public init(query: String) { self.query = query }
    }

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

                public let droidFragment: DroidFragment

                public enum CodingKeys: String, CodingKey {
                    case droidFragment
                }

                public init(from decoder: Decoder) throws { droidFragment = try DroidFragment(from: decoder) }
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
