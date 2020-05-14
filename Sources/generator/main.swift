import Foundation
import GraphQL
import Meta
import GraphQLGenerator
import ArgumentParser

struct Generator: ParsableCommand {
    
    static var configuration = CommandConfiguration(subcommands: [Generate.self, Download.self])
    
    struct Generate: ParsableCommand {
        
        @Option(name: .shortAndLong, default: "schema.graphql", help: "Path to schema file from working directory")
        var schema: String
        
        @Option(name: .shortAndLong, default: "GraphQL", help: "Path to directory containing .graphql files")
        var input: String
        
        @Option(name: .shortAndLong, default: "Generated.swift", help: "Path to output file")
        var output: String

        func run() throws {
            try GraphQLGenerator.Generator(schemaPath: schema, inputPath: input, outputPath: output).generate()
        }
    }
    
    struct Download: ParsableCommand {
        
        @ArgumentParser.Argument(help: "Url to download schema from")
        var url: String
        
        func run() throws {
            
        }
    }
}

Generator.main()
