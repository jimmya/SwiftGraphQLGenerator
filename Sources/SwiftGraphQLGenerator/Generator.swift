import Foundation
import Rainbow
import GraphQL
import Meta

public final class Generator {
    
    private let schemaPath: String
    private let inputPath: String
    private let outputPath: String
    private let fileManager: FileManager
    
    private var objectDefinitions: [String: ObjectTypeDefinition] = [:]
    private var unionDefinitions: [String: UnionTypeDefinition] = [:]
    private var interfaceDefinitions: [String: InterfaceTypeDefinition] = [:]
    private var enumDefinitions: [String: EnumTypeDefinition] = [:]
    
    private var usedEnumTypes: [String] = []
    
    public init(schemaPath: String,
                inputPath: String,
                outputPath: String,
                fileManager: FileManager = .default) {
        self.schemaPath = schemaPath
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.fileManager = fileManager
    }
    
    public func generate() throws {
        let workingDirectory = getWorkingDirectory()
        
        let schemaData = try Data(contentsOf: URL(fileURLWithPath: workingDirectory + schemaPath))
        guard let schemaString = String(data: schemaData, encoding: .utf8) else {
            throw GraphQLGeneratorError.schemaNotRead
        }

        var objects: [String] = []
        let enumerator = fileManager.enumerator(atPath: inputPath)
        while let element = enumerator?.nextObject() as? String {
            guard element.hasSuffix(".graphql") else { continue }
            let data = try Data(contentsOf: URL(fileURLWithPath: workingDirectory + inputPath + "/" + element))
            guard let string = String(data: data, encoding: .utf8) else {
                print("Unable to read contents of \(element)".red)
                continue
            }
            objects.append(string)
        }
        let combinedObjects = objects.joined(separator: "\n")
        
        let schema = try parse(source: .init(body: schemaString))
        let document = try parse(source: .init(body: combinedObjects))
        
        var members: [FileBodyMember] = []
        
        schema.definitions.forEach { definition in
            switch definition {
                case let objectDefinition as ObjectTypeDefinition:
                    objectDefinitions[objectDefinition.name.value] = objectDefinition
                case let unionDefinition as UnionTypeDefinition:
                    unionDefinitions[unionDefinition.name.value] = unionDefinition
                case let interfaceDefinition as InterfaceTypeDefinition:
                    interfaceDefinitions[interfaceDefinition.name.value] = interfaceDefinition
                case let enumDefinition as EnumTypeDefinition:
                    enumDefinitions[enumDefinition.name.value] = enumDefinition
                default: return
            }
        }
        
        for (index, definition) in document.definitions.enumerated() {
            switch definition {
                case let operation as OperationDefinition:
//                    let start = operation.loc?.start ?? 0
//                    let end = document.definitions[safe: index + 1]?.loc?.start ?? combinedObjects.count
//                    let startIndex = combinedObjects.index(combinedObjects.startIndex, offsetBy: start)
//                    let index = combinedObjects.index(startIndex, offsetBy: end - start)
//                    let definition = combinedObjects[startIndex..<index].trimmingCharacters(in: .newlines)
                    // TODO add graphQL definition to generated struct to be used in request
                    try members.append(mapOperation(operation, schema: schema))
                case let fragment as FragmentDefinition:
                    // TODO add graphQL fragment definition to generated struct and append this to generated operations using this fragment. See commented section in operation to fetch definition
                    try members.append(contentsOf: mapFragment(fragment, schema: schema))
                default: fatalError("Unsupported definition")
            }
            members.append(EmptyLine())
        }
        usedEnumTypes.forEach { enumType in
            guard let match = enumDefinitions[enumType] else { return }
            var enumNode = Meta.Type(identifier: .named(enumType)).with(kind: .enum(indirect: false)).adding(inheritedType: .string).adding(inheritedTypes: [.decodable, .equatable]).with(accessLevel: .public)
            match.values.forEach { value in
                enumNode = enumNode.adding(member: Case(name: value.name.value))
            }
            members.append(enumNode)
        }
        let file = File(name: "Meta")
            .with(imports: [Import(name: "Foundation")])
            .with(header: [.empty,
                           .comment("Generated by GraphQLGenerator"),
                           .comment("DO NOT MODIFY!"),
                           .empty])
            .adding(members: members)
        let outputDirectoryPath = outputPath.split(separator: "/").dropLast().joined(separator: "/")
        try fileManager.createDirectory(atPath: outputDirectoryPath, withIntermediateDirectories: true, attributes: nil)
        let created = fileManager.createFile(atPath: outputPath, contents: file.swiftString.data(using: .utf8), attributes: nil)
        if created {
            print("Generated `\(outputPath)` file".green)
        } else {
            print("Error writing to `\(outputPath)".red)
        }
    }
    
    func resolveType(_ type: GraphQL.`Type`, wrapInTopLevelOptional: Bool = true) throws -> (TypeIdentifier, String, Bool) {
        var typeIdentifier: TypeIdentifier?
        var isOptional = false
        var typeName: String?
        for type in type.toArray().reversed() {
            if type is NonNullType {
                isOptional = false
            } else if isOptional {
                typeIdentifier = .optional(wrapped: typeIdentifier)
                isOptional = false
            } else if type is ListType {
                typeIdentifier = .array(element: typeIdentifier)
                isOptional = true
            } else if let named = type as? NamedType {
                let sanitizedType: TypeIdentifierName = Primitives(rawValue: named.name.value)?.type ?? .custom(named.name.value)
                typeIdentifier = .init(name: sanitizedType)
                isOptional = true
                typeName = named.name.value
            }
        }
        if isOptional, wrapInTopLevelOptional {
            typeIdentifier = .optional(wrapped: typeIdentifier)
        }
        guard let identifier = typeIdentifier, let name = typeName else {
            throw GraphQLGeneratorError.namelessType
        }
        return (identifier, name, isOptional)
    }

    func mapType(_ type: GraphQL.`Type`, name: String) throws -> (TypeBodyMember, String) {
        let (identifier, typeName, _) = try resolveType(type)
        return (Property(variable:
            Variable(name: name)
                .with(immutable: true)
                .with(type: identifier)
        ).with(accessLevel: .public), typeName)
    }

    func mapOperation(_ operation: OperationDefinition, schema: Document) throws -> FileBodyMember {
        guard let name = operation.name?.value else {
            throw GraphQLGeneratorError.noQueryName
        }
        print("Generating operation `\(name)` of type `\(operation.operation)`".yellow)
        var member = Meta.Type(identifier: .init(name: name)).with(kind: .struct).adding(inheritedTypes: [.codable, .equatable]).with(accessLevel: .public)
        if !operation.variableDefinitions.isEmpty {
            member = member.adding(member: EmptyLine())
        }
        try operation.variableDefinitions.forEach { variable in
            member = member.adding(member: try mapType(variable.type, name: variable.variable.name.value).0)
        }
        member = member.adding(member: EmptyLine())
        var data = Meta.Type(identifier: .init(name: "Data")).with(kind: .struct).adding(inheritedTypes: [.decodable, .equatable]).with(accessLevel: .public)
        try operation.selectionSet.selections.forEach { selection in
            switch selection {
                case let field as Field:
                    let propertyName = field.alias?.value ?? field.name.value
                    let type: FieldDefinition?
                    switch operation.operation {
                        case .query:
                            type = objectDefinitions["Query"]?.fields.first(where: { $0.name.value == field.name.value })
                        case .mutation:
                            type = objectDefinitions["Mutation"]?.fields.first(where: { $0.name.value == field.name.value })
                        case .subscription: fatalError("Not supported")
                    }
                    guard let queriedType = type else { throw GraphQLGeneratorError.unexpectedType }
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

    func generateCodingKeys(_ selectionSet: SelectionSet) -> TypeBodyMember {
        var enumType = Meta.Type(identifier: .named("CodingKeys")).with(kind: .enum(indirect: false)).adding(inheritedType: .string).adding(inheritedType: .named("CodingKey")).with(accessLevel: .public)
        selectionSet.selections.forEach { selection in
            if let field = selection as? Field {
                let name = field.alias?.value ?? field.name.value
                enumType = enumType.adding(member: Case(name: name))
            } else if let fragment = selection as? FragmentSpread {
                let name = fragment.name.value.lowercasingFirstLetter()
                enumType = enumType.adding(member: Case(name: name))
            }
        }
        return enumType
    }

    func generateInit(_ selectionSet: SelectionSet, definition: ObjectTypeDefinition) throws -> TypeBodyMember {
        var function = Function(kind: .`init`).with(throws: true).with(accessLevel: .public)
        .adding(parameter:
            FunctionParameter(alias: "from", name: "decoder", type: .named("Decoder"))
            )
        if selectionSet.selections.contains(where: { $0 is Field }) { // Only add values keys if we are going to use it
            function = function.adding(member: Assignment(
                variable: Variable(name: "values"),
                value: .try | .dot(.named("decoder"), .named("container")) | .call(Tuple().adding(parameter: TupleParameter(name: "keyedBy", value: Value.reference(.dot(.named("CodingKeys"), .named("self"))))))
            ))
        }
        try selectionSet.selections.forEach { selection in
            if let field = selection as? Field {
                let name = field.alias?.value ?? field.name.value
                guard let definition = definition.fields.first(where: { $0.name.value == field.name.value }) else { return }
                let (property, _, isOptional) = try resolveType(definition.type, wrapInTopLevelOptional: false)
                let reference = Reference.type(property)
                let method: Reference = isOptional ? .named("decodeIfPresent") : .named("decode")
                 let tuple = Tuple()
                    .adding(parameter: TupleParameter(value: Value.reference(.dot(reference, .named("self")))))
                    .adding(parameter: TupleParameter(name: "forKey", value: Value.reference(.dot(.named("CodingKeys"), .named(name)))))
                function = function.adding(member: Assignment(variable: Reference.named(name), value: .try |
                    .dot(.named("values"), method) |
                    .call(tuple)))
            } else if let fragment = selection as? FragmentSpread {
                let name = fragment.name.value.lowercasingFirstLetter()
                let tuple = Tuple().adding(parameter: TupleParameter(name: "from", value: Value.reference(.named("decoder"))))
                function = function.adding(member: Assignment(variable: Reference.named(name), value: .try | .named(fragment.name.value) | .call(tuple)))
            }
        }
        return function
    }
    
    func generateInit(_ selectionSet: SelectionSet, definition: InterfaceTypeDefinition, inlineFragmentDefinitions: [(type: String, fragment: InlineFragment, count: Int?)]) throws -> TypeBodyMember {
        var function = Function(kind: .`init`).with(throws: true).with(accessLevel: .public)
        .adding(parameter:
            FunctionParameter(alias: "from", name: "decoder", type: .named("Decoder"))
            )
        if selectionSet.selections.contains(where: { $0 is Field }) { // Only add values keys if we are going to use it
            function = function.adding(member: Assignment(
                variable: Variable(name: "values"),
                value: .try | .dot(.named("decoder"), .named("container")) | .call(Tuple().adding(parameter: TupleParameter(name: "keyedBy", value: Value.reference(.dot(.named("CodingKeys"), .named("self"))))))
            ))
        }
        try selectionSet.selections.forEach { selection in
            if let field = selection as? Field {
                let name = field.alias?.value ?? field.name.value
                guard let definition = definition.fields.first(where: { $0.name.value == field.name.value }) else { return }
                let (property, _, isOptional) = try resolveType(definition.type, wrapInTopLevelOptional: false)
                let reference = Reference.type(property)
                let method: Reference = isOptional ? .named("decodeIfPresent") : .named("decode")
                 let tuple = Tuple()
                    .adding(parameter: TupleParameter(value: Value.reference(.dot(reference, .named("self")))))
                    .adding(parameter: TupleParameter(name: "forKey", value: Value.reference(.dot(.named("CodingKeys"), .named(name)))))
                function = function.adding(member: Assignment(variable: Reference.named(name), value: .try |
                    .dot(.named("values"), method) |
                    .call(tuple)))
            } else if let fragment = selection as? FragmentSpread {
                let name = fragment.name.value.lowercasingFirstLetter()
                let tuple = Tuple().adding(parameter: TupleParameter(name: "from", value: Value.reference(.named("decoder"))))
                function = function.adding(member: Assignment(variable: Reference.named(name), value: .try | .named(fragment.name.value) | .call(tuple)))
            }
        }
        let inlineFragmentTypes = Set(inlineFragmentDefinitions.map { $0.type })
        if inlineFragmentTypes.count > 0 {
            function = function.adding(member: Assignment(
                variable: Variable(name: "type"),
                value: .try | .dot(.named("values"), .named("decode")) | .call(Tuple().adding(parameter: TupleParameter(value: Value.reference(.dot(.type(.named("String")), .named("self"))))).adding(parameter: TupleParameter(name: "forKey", value: Value.reference(.named(".__typename")))))))
            var initSwitch = Switch(reference: .named("type"))
            inlineFragmentTypes.forEach { type in
                var switchCase = SwitchCase(name: .raw("\"\(type)\""))
                inlineFragmentDefinitions.forEach { (current) in
                    let (fragmentType, _, count) = current
                    let typeName: String
                    if let count = count {
                        typeName = fragmentType + "\(count)"
                    } else {
                        typeName = fragmentType
                    }
                    if fragmentType == type {
                        let variable = .optionalTry | .named(typeName) | .tuple(Tuple().adding(parameter: TupleParameter(name: "from", value: Value.reference(.named("decoder")))))
                        let assignment = Assignment(variable: Reference.named("as" + typeName), value: variable)
                        switchCase = switchCase.adding(member: assignment)
                    } else {
                        let assignment = Assignment(variable: Reference.named("as" + typeName), value: Value.nil)
                        switchCase = switchCase.adding(member: assignment)
                    }
                }
                initSwitch = initSwitch.adding(case: switchCase)
            }
            var switchCase = SwitchCase(name: .default)
            inlineFragmentDefinitions.forEach { (current) in
                let (fragmentType, _, count) = current
                let typeName: String
                if let count = count {
                    typeName = fragmentType + "\(count)"
                } else {
                    typeName = fragmentType
                }
                let assignment = Assignment(variable: Reference.named("as" + typeName), value: Value.nil)
                switchCase = switchCase.adding(member: assignment)
            }
            initSwitch = initSwitch.adding(case: switchCase)
            function = function.adding(member: initSwitch)
            
        }
        return function
    }

    func mapInterfaceSelectionSet(_ selectionSet: SelectionSet, typeName: String, name: String? = nil, definition: InterfaceTypeDefinition, definitions: [Definition]) throws -> [TypeBodyMember & FileBodyMember] {
        var selectionSetType = Meta.Type(identifier: .init(name: name ?? typeName)).with(kind: .struct).adding(inheritedTypes: [.decodable, .equatable]).with(accessLevel: .public)
        selectionSetType = selectionSetType.adding(member: EmptyLine())
        
        let inlineFragmentNames = selectionSet.selections.compactMap { ($0 as? InlineFragment)?.typeCondition?.name.value }
        let inlineFragments = selectionSet.selections.compactMap { $0 as? InlineFragment}
        let inlineFragmentDefinitions: [(type: String, fragment: InlineFragment, count: Int?)] = inlineFragments.reduce(into: []) { (result, fragment) in
            guard let type = fragment.typeCondition?.name.value else { return }
            let typeCount = inlineFragments.filter { $0.typeCondition?.name.value == type }.count
            let count: Int?
            if let currentCount = result.last(where: { $0.type == type })?.count {
                count = currentCount + 1
            } else {
                count = typeCount > 1 ? 1 : nil
            }
            result.append((type, fragment, count))
        }
        
        var selectionSets: [(SelectionSet, String)] = []
        try selectionSet.selections.forEach { selection in
            guard let field = selection as? Field else { return }
                guard let definition = definition.fields.first(where: { $0.name.value == field.name.value }) else { return }
                let name = field.alias?.value ?? field.name.value
                let type = try mapType(definition.type, name: name)
                let isEnum = enumDefinitions.keys.contains(type.1)
                if isEnum {
                    usedEnumTypes.append(type.1)
                }
                selectionSetType = selectionSetType.adding(member: type.0)
                if let selectionSet = field.selectionSet {
                    selectionSets.append((selectionSet, type.1))
                }
        }
        inlineFragmentDefinitions.forEach { item in
            let (type, _, count) = item
            let typeName: String
            if let count = count {
                typeName = type + "\(count)"
            } else {
                typeName = type
            }
            selectionSetType = selectionSetType.adding(member: Property(variable:
                Variable(name: "as\(typeName)")
                    .with(immutable: true)
                    .with(type: .optional(wrapped: .init(name: typeName)))
            ).with(accessLevel: .public))
        }
        selectionSetType = selectionSetType.adding(member: EmptyLine())
        selectionSetType = selectionSetType.adding(member: generateCodingKeys(selectionSet))
        selectionSetType = selectionSetType.adding(member: EmptyLine())
        selectionSetType = selectionSetType.adding(member: try generateInit(selectionSet, definition: definition, inlineFragmentDefinitions: inlineFragmentDefinitions))
        try selectionSets.forEach { set in
            let (selectionSet, name) = set
            selectionSetType = selectionSetType.adding(member: EmptyLine())
            selectionSetType = selectionSetType.adding(members: try mapSelectionSet(selectionSet, typeName: name, definitions: definitions))
        }
        
        try inlineFragmentDefinitions.forEach { item in
            let (type, fragment, count) = item
            let typeName: String
            if let count = count {
                typeName = type + "\(count)"
            } else {
                typeName = type
            }
            selectionSetType = selectionSetType.adding(member: EmptyLine())
            selectionSetType = selectionSetType.adding(members: try mapSelectionSet(fragment.selectionSet, typeName: type, name: typeName, definitions: definitions))
        }
        
        return [selectionSetType]
    }
    
    func mapObjectSelectionSet(_ selectionSet: SelectionSet, typeName: String, name: String? = nil, definition: ObjectTypeDefinition, definitions: [Definition]) throws -> TypeBodyMember & FileBodyMember {
        var selectionSetType = Meta.Type(identifier: .init(name: name ?? typeName)).with(kind: .struct).adding(inheritedTypes: [.decodable, .equatable]).with(accessLevel: .public)
        selectionSetType = selectionSetType.adding(member: EmptyLine())
        
        var selectionSets: [(SelectionSet, String)] = []
        
        try selectionSet.selections.forEach { selection in
            if let field = selection as? Field {
                guard let definition = definition.fields.first(where: { $0.name.value == field.name.value }) else { return }
                let name = field.alias?.value ?? field.name.value
                let type = try mapType(definition.type, name: name)
                let isEnum = enumDefinitions.keys.contains(type.1)
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
        selectionSetType = selectionSetType.adding(member: generateCodingKeys(selectionSet))
        selectionSetType = selectionSetType.adding(member: EmptyLine())
        selectionSetType = selectionSetType.adding(member: try generateInit(selectionSet, definition: definition))
        try selectionSets.forEach { set in
            let (selectionSet, name) = set
            selectionSetType = selectionSetType.adding(member: EmptyLine())
            selectionSetType = selectionSetType.adding(members: try mapSelectionSet(selectionSet, typeName: name, definitions: definitions))
        }
        
        return selectionSetType
    }

    func mapUnionSelectionSet(_ selectionSet: SelectionSet, typeName: String, name: String? = nil, definition: UnionTypeDefinition, definitions: [Definition]) throws -> TypeBodyMember & FileBodyMember {
        guard selectionSet.selections.contains(where: { ($0 as? Field)?.name.value == "__typename" }) else {
            throw GraphQLGeneratorError.unionWithoutTypename
        }
        var enumType = Meta.Type(identifier: .named(typeName)).with(kind: .enum(indirect: false)).adding(inheritedTypes: [.decodable, .equatable]).with(accessLevel: .public)
        enumType = enumType.adding(member: EmptyLine())
        definition.types.forEach { type in
            let name = type.name.value.lowercasingFirstLetter()
            let enumCase = Case(name: name).adding(parameter: CaseParameter(name: name, type: .named(type.name.value)))
            enumType = enumType.adding(member: enumCase)
        }
        
        enumType = enumType.adding(member: EmptyLine())
        var typeEnum = Meta.Type(identifier: .named("ItemType")).with(kind: .enum(indirect: false)).adding(inheritedType: .string).adding(inheritedType: .decodable)
        definition.types.forEach { type in
            typeEnum = typeEnum.adding(member: Case(name: type.name.value.lowercasingFirstLetter()).with(value: .string(type.name.value)))
        }
        enumType = enumType.adding(member: typeEnum)
        
        enumType = enumType.adding(member: EmptyLine())
        var codingKeyEnum = Meta.Type(identifier: .named("ItemTypeKey")).with(kind: .enum(indirect: false)).adding(inheritedType: .string).adding(inheritedType: .named("CodingKey"))
        codingKeyEnum = codingKeyEnum.adding(member: Case(name: "typeName").with(value: .string("__typename")))
        
        enumType = enumType.adding(member: codingKeyEnum)
        enumType = enumType.adding(member: EmptyLine())
        
        var initFunction = Function(kind: .`init`).with(throws: true).with(accessLevel: .public)
        .adding(parameter:
            FunctionParameter(alias: "from", name: "decoder", type: .named("Decoder"))
            )
        initFunction = initFunction.adding(member: Assignment(
            variable: Variable(name: "typeValues"),
            value: .try | .dot(.named("decoder"), .named("container")) | .call(Tuple().adding(parameter: TupleParameter(name: "keyedBy", value: Value.reference(.dot(.named("ItemTypeKey"), .named("self"))))))))
        initFunction = initFunction.adding(member: Assignment(
        variable: Variable(name: "type"),
        value: .try | .dot(.named("typeValues"), .named("decode")) | .call(Tuple().adding(parameter: TupleParameter(value: Value.reference(.dot(.type(.named("ItemType")), .named("self"))))).adding(parameter: TupleParameter(name: "forKey", value: Value.reference(.named(".typeName")))))))
        
        var initSwitch = Switch(reference: .named("type"))
        definition.types.forEach { type in
            let name = type.name.value.lowercasingFirstLetter()
            var switchCase = SwitchCase(name: .custom(name))
            let variable = .try | .named(type.name.value) | .tuple(Tuple().adding(parameter: TupleParameter(name: "from", value: Value.reference(.named("decoder")))))
            let assignment = Assignment(variable: Reference.named("self"), value: .named(".\(name)") | .call(Tuple().adding(parameter: TupleParameter(name: name, value: variable))))
            switchCase = switchCase.adding(member: assignment)
            initSwitch = initSwitch.adding(case: switchCase)
        }

        initFunction = initFunction.adding(member: initSwitch)
        
        enumType = enumType.adding(member: initFunction)
        
        try definition.types.forEach { type in
            enumType = enumType.adding(member: EmptyLine())
            let inlineFragments = selectionSet.selections.compactMap { $0 as? InlineFragment }
            if let selection = inlineFragments.first(where: { $0.typeCondition?.name.value == type.name.value }) {
                let items = try mapSelectionSet(selection.selectionSet, typeName: type.name.value, definitions: definitions)
                enumType = enumType.adding(members: items)
            } else {
                let item = Meta.Type(identifier: .init(name: type.name.value)).with(kind: .struct).adding(inheritedTypes: [.decodable, .equatable]).with(accessLevel: .public)
                enumType = enumType.adding(member: item)
            }
        }
        return enumType
    }

    func mapSelectionSet(_ selectionSet: SelectionSet, typeName: String, name: String? = nil, definitions: [Definition]) throws -> [TypeBodyMember & FileBodyMember] {
        if let definition = unionDefinitions[typeName] {
            return try [mapUnionSelectionSet(selectionSet, typeName: typeName, name: name, definition: definition, definitions: definitions)]
        } else if let definition = objectDefinitions[typeName] {
            return try [mapObjectSelectionSet(selectionSet, typeName: typeName, name: name, definition: definition, definitions: definitions)]
        } else if let definition = interfaceDefinitions[typeName] {
            return try mapInterfaceSelectionSet(selectionSet, typeName: typeName, name: name, definition: definition, definitions: definitions)
        }
        throw GraphQLGeneratorError.unexpectedType
    }

    func mapFragment(_ fragment: FragmentDefinition, schema: Document) throws -> [FileBodyMember & TypeBodyMember] {
        print("Generating fragment `\(fragment.name.value)`".yellow)
        return try mapSelectionSet(fragment.selectionSet, typeName: fragment.typeCondition.name.value, name: fragment.name.value, definitions: schema.definitions)
    }
}

private extension Generator {
    
    func getWorkingDirectory() -> String {
        let cwd = getcwd(nil, Int(PATH_MAX))
        defer {
            free(cwd)
        }
        if let cwd = cwd, let string = String(validatingUTF8: cwd) {
            return string + "/"
        } else {
            return "./"
        }
    }
}
