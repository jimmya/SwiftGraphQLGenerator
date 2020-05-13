import Foundation
import GraphQL
import Meta
import GraphQLGenerator

let start = Date()

public extension Array {
    
    subscript (safe index: Int) -> Element? {
        get {
            return index < count && index >= 0 ? self[index] : nil
        }
        set {
            if let element = newValue, index < count, index >= 0 {
                self[index] = element
            }
        }
    }
}

let cwd = getcwd(nil, Int(PATH_MAX))
defer {
    free(cwd)
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + self.lowercased().dropFirst()
    }
    
    func lowercasingFirstLetter() -> String {
        return prefix(1).lowercased() + self.dropFirst()
    }
    
    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
    
    mutating func lowercaseFirstLetter() {
        self = self.lowercasingFirstLetter()
    }
}

let workingDirectory: String

if let cwd = cwd, let string = String(validatingUTF8: cwd) {
    workingDirectory = string
} else {
    workingDirectory = "./"
}

enum GraphQLGeneratorError: Error {
    case noQueryName
    case invalidSelectionType
    case namelessType
    case unexpectedType
    case unionWithoutTypename
}

let schemaData = try Data(contentsOf: URL(fileURLWithPath: workingDirectory + "/schema.graphql"))
let schemaString = String(data: schemaData, encoding: .utf8)!

let queryData = try Data(contentsOf: URL(fileURLWithPath: workingDirectory + "/Stores.graphql"))
let queryString = String(data: queryData, encoding: .utf8)!

var members: [FileBodyMember] = []

struct TypeProperties {
    
    let isArray: Bool
    let isOptional: Bool
    let isArrayValueOptional: Bool
    var typeName: String
}

enum Primitives: String {
    case String
    case Int
    case Float
    case Boolean
    case ID
    
    var typeName: String {
        switch self {
            case .ID: return "String"
            case .Boolean: return "Bool"
            default: return rawValue
        }
    }
}

func resolveType(_ type: GraphQL.`Type`) throws -> TypeProperties {
    var isArray = false
    var isOptional = true
    var isArrayValueOptional = true
    var typeName: String?
    var currentType: GraphQL.`Type`? = type
    repeat {
        if let named = currentType as? NamedType {
            typeName = named.name.value
            currentType = nil
        } else if let nonNull = currentType as? NonNullType {
            if isArray {
                isArrayValueOptional = false
            } else {
                isOptional = false
            }
            currentType = nonNull.type
        } else if let list = currentType as? ListType {
            isArray = true
            currentType = list.type
        }
    } while currentType != nil
    let sanitizedTypeName: String
    if let name = typeName {
        sanitizedTypeName = Primitives(rawValue: name)?.typeName ?? name
    } else {
        throw GraphQLGeneratorError.namelessType
    }
    return .init(isArray: isArray, isOptional: isOptional, isArrayValueOptional: isArrayValueOptional, typeName: sanitizedTypeName)
}

func mapType(_ type: GraphQL.`Type`, name: String) throws -> (TypeBodyMember, String) {
    let properties = try resolveType(type)
    let typeIsOptional = properties.isArray ? properties.isArrayValueOptional : properties.isOptional
    let objectType: TypeIdentifier = typeIsOptional ? .optional(wrapped: .named(properties.typeName)) : .named(properties.typeName)
    let type: TypeIdentifier
    if properties.isArray {
        type = properties.isOptional ? .optional(wrapped: .array(element: objectType)) : .array(element: objectType)
    } else {
        type = objectType
    }
    return (Property(variable:
        Variable(name: name)
            .with(immutable: true)
            .with(type: type)
    ).with(accessLevel: .public), properties.typeName)
}

func mapOperation(_ operation: OperationDefinition, schema: Document) throws -> FileBodyMember {
    guard let name = operation.name?.value else {
        throw GraphQLGeneratorError.noQueryName
    }
    var member = Meta.Type(identifier: .init(name: name)).with(kind: .struct).adding(inheritedType: .init(name: "Codable"))
    if !operation.variableDefinitions.isEmpty {
        member = member.adding(member: EmptyLine())
    }
    try operation.variableDefinitions.forEach { variable in
        member = member.adding(member: try mapType(variable.type, name: variable.variable.name.value).0)
    }
    member = member.adding(member: EmptyLine())
    var data = Meta.Type(identifier: .init(name: "Data")).with(kind: .struct).adding(inheritedType: .init(name: "Decodable"))
    try operation.selectionSet.selections.forEach { selection in
        switch selection {
            case let field as Field:
                let propertyName = field.alias?.value ?? field.name.value
                let objectDefinitions = schema.definitions.compactMap { $0 as? ObjectTypeDefinition }
                guard let query = objectDefinitions.first(where: { $0.name.value == "Query" }) else {
                    print("No query")
                    return
                }
                guard let queriedType = query.fields.first(where: { $0.name.value == field.name.value }) else {
                    print("No queried type")
                    return
                }
                let property = try mapType(queriedType.type, name: propertyName)
                data = data.adding(member: EmptyLine())
                data = data.adding(member: property.0)
                if let selectionSet = field.selectionSet {
                    let test = try mapSelectionSet(selectionSet, typeName: property.1, definitions: schema.definitions)
                    data = data.adding(member: EmptyLine())
                    data = data.adding(members: test)
            }
            case let fragment as FragmentSpread:
                print("TODO")
            case let inlineFragment as InlineFragment:
                print("TODO")
            default: throw GraphQLGeneratorError.invalidSelectionType
        }
    }
    member = member.adding(member: data)
    return member
}

var usedEnumTypes: [String] = []

func generateInit(_ selectionSet: SelectionSet, definition: ObjectTypeDefinition) throws -> TypeBodyMember {
    var function = Function(kind: .`init`).with(throws: true)
    .adding(parameter:
        FunctionParameter(alias: "with", name: "decoder", type: .named("Decoder"))
        )
        .adding(member: Assignment(
        variable: Variable(name: "values"),
        value: .try | .dot(.named("decoder"), .named("container")) | .call(Tuple().adding(parameter: TupleParameter(name: "keyedBy", value: Value.reference(.dot(.named("CodingKeys"), .named("self"))))))
    ))
    try selectionSet.selections.forEach { selection in
        if let field = selection as? Field {
            let name = field.alias?.value ?? field.name.value
            guard let definition = definition.fields.first(where: { $0.name.value == field.name.value }) else { return }
            let properties = try resolveType(definition.type)
            let reference: Reference = properties.isArray ? Reference.named("[\(properties.typeName)]") : Reference.named(properties.typeName)
            if properties.isOptional {
                let tuple = Tuple()
                    .adding(parameter: TupleParameter(value: Value.reference(.dot(reference, .named("self")))))
                    .adding(parameter: TupleParameter(name: "forKey", value: Value.reference(.dot(.named("CodingKeys"), .named(name)))))
                function = function.adding(member: Assignment(variable: Reference.named(name), value: .try |
                    .dot(.named("values"), .named("decodeIfPresent")) |
                    .call(tuple)))
            } else {
                let tuple = Tuple()
                    .adding(parameter: TupleParameter(value: Value.reference(.dot(reference, .named("self")))))
                    .adding(parameter: TupleParameter(name: "forKey", value: Value.reference(.dot(.named("CodingKeys"), .named(name)))))
                function = function.adding(member: Assignment(variable: Reference.named(name), value: .try |
                    .dot(.named("values"), .named("decode")) |
                    .call(tuple)))
            }
        } else if let fragment = selection as? FragmentSpread {
            let name = fragment.name.value.lowercasingFirstLetter()
            let tuple = Tuple().adding(parameter: TupleParameter(name: "with", value: Value.reference(.named("decoder"))))
            function = function.adding(member: Assignment(variable: Reference.named(name), value: .try | .named(fragment.name.value) | .call(tuple)))
        }
    }
    return function
}

func mapObjectSelectionSet(_ selectionSet: SelectionSet, typeName: String, name: String? = nil, definition: ObjectTypeDefinition, definitions: [Definition]) throws -> TypeBodyMember & FileBodyMember {
    var selectionSetType = Meta.Type(identifier: .init(name: name ?? typeName)).with(kind: .struct).adding(inheritedType: .init(name: "Decodable"))
    selectionSetType = selectionSetType.adding(member: EmptyLine())
    
    var selectionSets: [(SelectionSet, String)] = []
    
    try selectionSet.selections.forEach { selection in
        if let field = selection as? Field {
            guard let definition = definition.fields.first(where: { $0.name.value == field.name.value }) else { return }
            let name = field.alias?.value ?? field.name.value
            let type = try mapType(definition.type, name: name)
            let isEnum = definitions.compactMap { $0 as? EnumTypeDefinition}.contains(where: { $0.name.value == type.1 })
            if isEnum {
                usedEnumTypes.append(type.1)
            }
            selectionSetType = selectionSetType.adding(member: type.0)
            if let selectionSet = field.selectionSet {
                selectionSets.append((selectionSet, type.1))
            }
        } else if let fragment = selection as? FragmentSpread {
            selectionSetType = selectionSetType.adding(member: Property(variable:
                Variable(name: fragment.name.value.lowercasingFirstLetter())
                    .with(immutable: true)
                    .with(type: .named(fragment.name.value))
            ).with(accessLevel: .public))
        }
    }
    selectionSetType = selectionSetType.adding(member: EmptyLine())
    selectionSetType = selectionSetType.adding(member: try generateInit(selectionSet, definition: definition))
    try selectionSets.forEach { set in
        let (selectionSet, name) = set
        selectionSetType = selectionSetType.adding(member: EmptyLine())
        selectionSetType = selectionSetType.adding(members: try mapSelectionSet(selectionSet, typeName: name, definitions: definitions))
    }
    
    return selectionSetType
}

func mapUnionSelectionSet(_ selectionSet: SelectionSet, typeName: String, name: String? = nil, definition: UnionTypeDefinition, definitions: [Definition]) throws -> [TypeBodyMember & FileBodyMember] {
    guard selectionSet.selections.contains(where: { ($0 as? Field)?.name.value == "__typename" }) else {
        throw GraphQLGeneratorError.unionWithoutTypename
    }
    var enumType = Meta.Type(identifier: .named(typeName)).with(kind: .enum(indirect: false)).adding(inheritedType: .named("Decodable")).with(accessLevel: .public)
    enumType = enumType.adding(member: EmptyLine())
    var nestedFiels: [GraphQL.Field] = []
    var inlineFragmentSelectionSets: [(SelectionSet, String)] = []
    selectionSet.selections.forEach { selection in
        if let field = selection as? Field {
            nestedFiels.append(field)
        } else if let inlineFragment = selection as? InlineFragment {
            guard let caseTypeName = inlineFragment.typeCondition?.name.value else { return }
            let name = caseTypeName.replacingOccurrences(of: typeName, with: "").lowercasingFirstLetter()
            let enumCase = Case(name: name).adding(parameter: CaseParameter(name: name, type: .named(caseTypeName)))
            enumType = enumType.adding(member: enumCase)
            inlineFragmentSelectionSets.append((inlineFragment.selectionSet, caseTypeName))
        }
    }
    
    enumType = enumType.adding(member: EmptyLine())
    var codingKeyEnum = Meta.Type(identifier: .named("ItemTypeKey")).with(kind: .enum(indirect: false)).adding(inheritedType: .string).adding(inheritedType: .named("CodingKey"))
    codingKeyEnum = codingKeyEnum.adding(member: Case(name: "typeName").with(value: .string("__typename")))
    
    enumType = enumType.adding(member: codingKeyEnum)
    enumType = enumType.adding(member: EmptyLine())
    
    var initFunction = Function(kind: .`init`).with(throws: true)
    .adding(parameter:
        FunctionParameter(alias: "from", name: "decoder", type: .named("Decoder"))
        )
    initFunction = initFunction.adding(member: Assignment(
        variable: Variable(name: "typeValues"),
        value: .try | .dot(.named("decoder"), .named("container")) | .call(Tuple().adding(parameter: TupleParameter(name: "keyedBy", value: Value.reference(.dot(.named("ItemTypeKey"), .named("self"))))))))
    initFunction = initFunction.adding(member: Assignment(
    variable: Variable(name: "type"),
    value: .try | .dot(.named("typeValues"), .named("decode")) | .call(Tuple().adding(parameter: TupleParameter(value: Value.reference(.dot(.named("String"), .named("self"))))).adding(parameter: TupleParameter(name: "forKey", value: Value.reference(.named(".typeName")))))))
    
    var initSwitch = Switch(reference: .named("type"))
    selectionSet.selections.forEach { selection in
        guard let inlineFragment = selection as? InlineFragment else { return }
        guard let caseTypeName = inlineFragment.typeCondition?.name.value else { return }
        let name = caseTypeName.replacingOccurrences(of: typeName, with: "").lowercasingFirstLetter()
        var switchCase = SwitchCase(name: .nonEnum("\"\(caseTypeName)\""))
        let variable = .try | .named(caseTypeName) | .tuple(Tuple().adding(parameter: TupleParameter(name: "with", value: Value.reference(.named("decoder")))))
        let assignment = Assignment(variable: Reference.named("self"), value: .named(".\(name)") | .call(Tuple().adding(parameter: TupleParameter(name: name, value: variable))))
        switchCase = switchCase.adding(member: assignment)
        initSwitch = initSwitch.adding(case: switchCase)
    }
    
    let forKey = TupleParameter(name: "forKey", value: Value.reference(.dot(.named("ItemTypeKey"), .named("typeName"))))
    let errorIn = TupleParameter(name: "in", value: Value.reference(.named("typeValues")))
    let debugDescription = TupleParameter(name: "debugDescription", value: Value.string("Type \\(type) is not a valid type for \\(\(typeName).self)"))
    let throwing = Reference.throw | Reference.named("DecodingError.dataCorruptedError") | .call(Tuple().adding(parameter: forKey).adding(parameter: errorIn).adding(parameter: debugDescription))
    var switchCase = SwitchCase(name: .default)
    switchCase = switchCase.adding(member: throwing)
    initSwitch = initSwitch.adding(case: switchCase)
    initFunction = initFunction.adding(member: initSwitch)
    
    enumType = enumType.adding(member: initFunction)
    
    var members: [TypeBodyMember & FileBodyMember] = []
    try inlineFragmentSelectionSets.forEach { item in
        let (selectionSet, name) = item
        members.append(EmptyLine())
        let items = try mapSelectionSet(selectionSet, typeName: name, definitions: definitions)
        members.append(contentsOf: items)
    }
    return [enumType] + members
}

func mapSelectionSet(_ selectionSet: SelectionSet, typeName: String, name: String? = nil, definitions: [Definition]) throws -> [TypeBodyMember & FileBodyMember] {
    let objectDefinitions = definitions.compactMap { $0 as? ObjectTypeDefinition }
    let unionDefinitions = definitions.compactMap { $0 as? UnionTypeDefinition }
    let interfaceDefinitions = definitions.compactMap { $0 as? InterfaceTypeDefinition }
    if let definition = unionDefinitions.first(where: { $0.name.value == typeName }) {
        return try mapUnionSelectionSet(selectionSet, typeName: typeName, name: name, definition: definition, definitions: definitions)
    } else if let definition = objectDefinitions.first(where: { $0.name.value == typeName }) {
        return try [mapObjectSelectionSet(selectionSet, typeName: typeName, name: name, definition: definition, definitions: definitions)]
    } else if let definition = interfaceDefinitions.first(where: { $0.name.value == typeName }) {
        return []
    }
    throw GraphQLGeneratorError.unexpectedType
}

func mapFragment(_ fragment: FragmentDefinition, schema: Document) throws -> [FileBodyMember & TypeBodyMember] {
    return try mapSelectionSet(fragment.selectionSet, typeName: fragment.typeCondition.name.value, name: fragment.name.value, definitions: schema.definitions)
}

do {
    let schema = try parse(source: .init(body: schemaString))
    let document = try parse(source: .init(body: queryString))
    
    for (index, definition) in document.definitions.enumerated() {
        switch definition {
            case let operation as OperationDefinition:
                let start = operation.loc?.start ?? 0
                let end = document.definitions[safe: index + 1]?.loc?.start ?? queryString.count
                let startIndex = queryString.index(queryString.startIndex, offsetBy: start)
                let index = queryString.index(startIndex, offsetBy: end - start)
                let definition = queryString[queryString.startIndex..<index].trimmingCharacters(in: .newlines)
                print(definition)
                try members.append(mapOperation(operation, schema: schema))
            case let fragment as FragmentDefinition:
                let start = fragment.loc?.start ?? 0
                let end = document.definitions[safe: index + 1]?.loc?.start ?? queryString.count
                let startIndex = queryString.index(queryString.startIndex, offsetBy: start)
                let index = queryString.index(startIndex, offsetBy: end - start)
                let definition = queryString[startIndex..<index].trimmingCharacters(in: .newlines)
                print(definition)
                try members.append(contentsOf: mapFragment(fragment, schema: schema))
            default: fatalError("Unsupported definition")
        }
        members.append(EmptyLine())
    }
    let enumDefintions = schema.definitions.compactMap { $0 as? EnumTypeDefinition }
    usedEnumTypes.forEach { enumType in
        guard let match = enumDefintions.first(where: { $0.name.value == enumType }) else { return }
        var enumNode = Meta.Type(identifier: .named(enumType)).with(kind: .enum(indirect: false)).adding(inheritedType: .string).adding(inheritedType: .named("Decodable"))
        match.values.forEach { value in
            enumNode = enumNode.adding(member: Case(name: value.name.value))
        }
        members.append(enumNode)
    }
    let file = File(name: "Meta")
        .with(header: [.empty,
                       .comment("Generated by GraphQLGenerator"),
                       .comment("DO NOT MODIFY!"),
                       .empty])
        .adding(members: members)
    print(file.swiftString)
} catch {
    print(error)
}

let duration = Date().timeIntervalSince(start)
print(duration)
