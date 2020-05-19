import Foundation

let query = Search(variables: .init(query: ""))
var request = URLRequest(url: URL(string: "http://localhost:8080/graphql")!)
request.addValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpMethod = "POST"
request.httpBody = try JSONEncoder().encode(query)

let (data, response, error) = URLSession.shared.synchronousDataTask(with: request)
if let data = data {
    let result = try JSONDecoder().decode(GraphQLResponse<Search.Data>.self, from: data)
    let items = result.data.search?.compactMap { $0 } ?? []
    items.forEach { result in
        switch result {
            case .human(human: let human):
                print(human.name)
            case .droid(droid: let droid):
                print(droid.name)
            default:
                print("Starship")
        }
    }
} else {
    print(response.debugDescription)
    print(error.debugDescription)
}
