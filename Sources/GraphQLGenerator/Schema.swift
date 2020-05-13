import Foundation

public typealias ImageUrl = String
public typealias PageSize = Int

public struct Persons: Codable {

    public struct Data: Decodable {

        public let allPersons: Array<Person>

        public struct Person: Decodable {

            public let name: String
            public let films: Optional<Array<Film>>

            public init(with decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                name = try values.decode(String.self, forKey: CodingKeys.name)
                films = try values.decodeIfPresent([Film].self, forKey: CodingKeys.films)
            }

            public struct Film: Decodable {

                public let title: String
                public let characters: Optional<Array<Person>>

                public init(with decoder: Decoder) throws {
                    let values = try decoder.container(keyedBy: CodingKeys.self)
                    title = try values.decode(String.self, forKey: CodingKeys.title)
                    characters = try values.decodeIfPresent([Person].self, forKey: CodingKeys.characters)
                }

                public struct Person: Decodable {

                    public let id: String
                    public let personFragment: PersonFragment

                    public init(with decoder: Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        id = try values.decode(String.self, forKey: CodingKeys.id)
                        personFragment = try PersonFragment(with: decoder)
                    }
                }
            }
        }
    }
}

public struct PersonFragment: Decodable {

    public let birthYear: Optional<String>
    public let isPublished: Bool
    public let name: String
    public let hairColor: Optional<Array<PERSON_HAIR_COLOR>>
    public let height: Optional<Int>
    public let homeworld: Optional<Planet>

    public init(with decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        birthYear = try values.decodeIfPresent(String.self, forKey: CodingKeys.birthYear)
        isPublished = try values.decode(Bool.self, forKey: CodingKeys.isPublished)
        name = try values.decode(String.self, forKey: CodingKeys.name)
        hairColor = try values.decodeIfPresent([PERSON_HAIR_COLOR].self, forKey: CodingKeys.hairColor)
        height = try values.decodeIfPresent(Int.self, forKey: CodingKeys.height)
        homeworld = try values.decodeIfPresent(Planet.self, forKey: CodingKeys.homeworld)
    }

    public struct Planet: Decodable {

        public let name: String
        public let terrain: Optional<Array<String>>
        public let surfaceWater: Optional<Float>
        public let population: Optional<Float>
        public let residents: Optional<Array<Person>>

        public init(with decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            name = try values.decode(String.self, forKey: CodingKeys.name)
            terrain = try values.decodeIfPresent([String].self, forKey: CodingKeys.terrain)
            surfaceWater = try values.decodeIfPresent(Float.self, forKey: CodingKeys.surfaceWater)
            population = try values.decodeIfPresent(Float.self, forKey: CodingKeys.population)
            residents = try values.decodeIfPresent([Person].self, forKey: CodingKeys.residents)
        }

        public struct Person: Decodable {

            public let name: String

            public init(with decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                name = try values.decode(String.self, forKey: CodingKeys.name)
            }
        }
    }
}

public enum PERSON_HAIR_COLOR: String, Decodable {
    case AUBURN
    case BLACK
    case BLONDE
    case BROWN
    case GREY
    case UNKNOWN
    case WHITE
}
