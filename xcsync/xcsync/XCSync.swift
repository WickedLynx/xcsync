//
//  XCSync.swift
//  XAdder
//
//  Created by Harshad on 08/04/2018.
//  Copyright © 2018 Harshad Dange. All rights reserved.
//

import Foundation
import xcproj
import PathKit

struct XCSync {
    static func run() {
        let processInfo = ProcessInfo.processInfo
        do {
            let arguments = try processInfo.parseProgramArguments()
            try run(srcRoot: arguments.srcRoot, projectPath: arguments.projectPath, configurationPath: arguments.configurationPath)
            exit(0)
        } catch {
            print("<xcsync> ERROR: \(error)")
            exit(1)
        }
    }
    
    static func run(srcRoot: String, projectPath: String, configurationPath: String) throws {
        do {
            let project = try XcodeProj(path: Path(projectPath))
            let configurations = try Configuration.configurationsAt(path: configurationPath)
            for configuration in configurations {
                try project.sync(configuration: configuration, srcRoot: srcRoot)
            }
            try project.write(path: Path(projectPath))
        }
    }
}


struct Configuration: Decodable {
    let groupPath: String
    let filePath: String
    let target: String
    var name: String? {
        return groupPath.components(separatedBy: CharacterSet(charactersIn: "/")).last
    }
    
    static func configurationsAt(path: String) throws -> [Configuration] {
        do {
            let configData = try Data(contentsOf: URL(fileURLWithPath: path))
            return try JSONDecoder().decode([Configuration].self, from: configData)
        }
    }
}

enum XCSyncError: Error {
    case parentReferenceNotFound(String)
    case notEnoughArguments(String)
    case incorrectArguments(String)
}

extension ProcessInfo {
    struct XCSyncArguments {
        let srcRoot: String
        let projectPath: String
        let configurationPath: String
    }
    
    func parseProgramArguments() throws -> XCSyncArguments {
        let parameters = arguments.filter { $0.hasPrefix("-") }
        guard parameters.count > 2 else {
            throw XCSyncError.notEnoughArguments("\(parameters)")
        }
        let pathParameters = parameters.reduce ([String : String]()) { (partial, argument) -> [String : String] in
            var components = argument.components(separatedBy: CharacterSet(charactersIn: "="))
            guard components.count > 1 else { return partial }
            let key = components.removeFirst()
            let value = components.joined(separator: "=")
            var partialCopy = partial
            partialCopy[key] = value
            return partialCopy
        }
        
        guard let srcRoot = pathParameters["-srcRoot"], let projectPath = pathParameters["-projectPath"], let configurationPath = pathParameters["-configurationPath"] else {
            throw XCSyncError.incorrectArguments("\(parameters)")
        }
        return XCSyncArguments(srcRoot: srcRoot, projectPath: projectPath, configurationPath: configurationPath)
    }
}
