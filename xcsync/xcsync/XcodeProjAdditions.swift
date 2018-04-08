//
//  XcodeProjAdditions.swift
//  XAdder
//
//  Created by Harshad on 08/04/2018.
//  Copyright © 2018 Harshad Dange. All rights reserved.
//

import Foundation
import xcproj
import PathKit

extension XcodeProj {
    func sync(configuration: Configuration, srcRoot: String) throws {
        do {
            try removeGroup(for: configuration)
            let diskPath = (srcRoot as NSString).appendingPathComponent(configuration.filePath)
            let name = configuration.name ?? "Group"
            let parent = try parentGroup(for: configuration)
            try addGroup(named: name, rootPath: diskPath, in: parent.0, to: configuration.target)
            print("<xcsync> Synced: \(configuration.groupPath)")
        }
    }
    
    func findGroup(named: String, in parent: PBXGroup?) -> (PBXGroup, String)? {
        guard let  parent = parent else {
            guard let result = pbxproj.objects.groups.first(where: {$0.value.name == named || $0.value.path == named}) else {
                return nil
            }
            return (result.value, result.key)
        }
        guard let result = pbxproj.objects.groups.first(where: {($0.value.name == named || $0.value.path == named) && parent.children.contains($0.key)}) else { return nil }
        return (result.value, result.key)
    }
    
    func parentGroup(for configuration: Configuration) throws -> (PBXGroup, String) {
        var components = configuration.groupPath.components(separatedBy: CharacterSet(charactersIn: "/"))
        let _ = components.removeLast()
        let parent = components.reduce(nil) { (groupInfo, groupName) -> (PBXGroup, String)? in
            return findGroup(named: groupName, in: groupInfo?.0)
        }
        guard let rValue = parent else {
            throw XCSyncError.parentReferenceNotFound(configuration.groupPath)
        }
        return rValue
        
    }
    
    func removeGroup(for configuration: Configuration) throws {
        guard let name = configuration.groupPath.components(separatedBy: CharacterSet(charactersIn: "/")).last else { return }
        do {
            let parent = try parentGroup(for: configuration)
            removeGroup(named: name, from: parent.0)
        }
        
    }
    
    func addGroup(named: String, rootPath: String, in parent: PBXGroup, to targetName: String) throws {
        do {
            let result = addGroup(named: named, in: parent)
            let contents = try FileManager.default.contentsOfDirectory(atPath: rootPath)
            for path in contents {
                var isDirectory: ObjCBool = false
                let fullPath = (rootPath as NSString).appendingPathComponent(path)
                if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue && !path.contains(".xcassets") {
                        try addGroup(named: path, rootPath: fullPath, in: result.0, to: targetName)
                    } else {
                        switch FileType.from(name: path) {
                        case .source:
                            addSourceFile(named: path, at: path, in: result.0, to: targetName)
                        case .resource where !path.hasPrefix("."):
                            addResourceFile(named: path, at: path, in: result.0, to: targetName)
                        default:
                            break
                        }
                    }
                }
            }
        }
    }
    
    
    @discardableResult
    func addGroup(named groupName: String, in parent: PBXGroup) -> (PBXGroup, String) {
        let foodGroup = PBXGroup(children: [], sourceTree: .group, name: groupName, path: groupName, includeInIndex: nil, wrapsLines: nil, usesTabs: nil, indentWidth: nil, tabWidth: nil)
        let foodGroupRef = pbxproj.objects.generateReference(foodGroup, groupName)
        parent.children.append(foodGroupRef)
        pbxproj.objects.addObject(foodGroup, reference: foodGroupRef)
        return (foodGroup, foodGroupRef)
    }
    
    func removeGroup(named groupName: String, from parent: PBXGroup) {
        for child in parent.children {
            let foodGroups = pbxproj.objects.groups.filter { ($0.value.name == groupName || $0.value.path == groupName) && $0.key == child }
            for (key, value) in foodGroups {
                for child in value.children {
                    let element = pbxproj.objects.getFileElement(reference: child)
                    if let groupElement = element as? PBXGroup {
                        removeGroup(named: groupElement.name ?? groupElement.path ?? "", from: value)
                    } else if let _ = element as? PBXFileReference {
                        value.children = value.children.filter { $0 != child }
                        removeSourceFileWith(ref: child)
                    }
                }
                parent.children = parent.children.filter { $0 != key }
                pbxproj.objects.groups.removeValue(forKey: key)
            }
        }
    }
    
    func removeSourceFileWith(ref: String) {
        pbxproj.objects.fileReferences = pbxproj.objects.fileReferences.filter { $0.key != ref }
        guard let buildFile = pbxproj.objects.buildFiles.first(where: {$0.value.fileRef == ref }) else { return }
        pbxproj.objects.buildFiles = pbxproj.objects.buildFiles.filter { $0.key != buildFile.key }
        for phases in pbxproj.objects.sourcesBuildPhases {
            phases.value.files = phases.value.files.filter { $0 != buildFile.key }
        }
        for phases in pbxproj.objects.resourcesBuildPhases {
            phases.value.files = phases.value.files.filter { $0 != buildFile.key }
        }
        
    }
    
    func addSourceFile(named fileName: String, at path: String, in group: PBXGroup, to target: String) {
        let sourceFile = PBXFileReference(sourceTree: .group, name: fileName, fileEncoding: nil, explicitFileType: nil, lastKnownFileType: nil, path: path, includeInIndex: nil, wrapsLines: nil, usesTabs: nil, indentWidth: nil, tabWidth: nil, lineEnding: nil, languageSpecificationIdentifier: nil, xcLanguageSpecificationIdentifier: nil, plistStructureDefinitionIdentifier: nil)
        let sourceFileRef = pbxproj.objects.generateReference(sourceFile, fileName)
        group.children.append(sourceFileRef)
        pbxproj.objects.addObject(sourceFile, reference: sourceFileRef)
        
        guard let sourcesBuildPhase = pbxproj
            .objects.nativeTargets
            .values
            .first(where: {$0.name == target})
            .flatMap({ target -> PBXSourcesBuildPhase? in
                return pbxproj.objects.sourcesBuildPhases.first(where: { target.buildPhases.contains($0.key) })?.value
            }) else { return }
        
        let buildFile = PBXBuildFile(fileRef: sourceFileRef)
        let buildFileRef = pbxproj.objects.generateReference(buildFile, fileName)
        pbxproj.objects.addObject(buildFile, reference: buildFileRef)
        sourcesBuildPhase.files.append(buildFileRef)
    }
    
    func addResourceFile(named fileName: String, at path: String, in group: PBXGroup, to target: String) {
        let sourceFile = PBXFileReference(sourceTree: .group, name: fileName, fileEncoding: nil, explicitFileType: nil, lastKnownFileType: nil, path: path, includeInIndex: nil, wrapsLines: nil, usesTabs: nil, indentWidth: nil, tabWidth: nil, lineEnding: nil, languageSpecificationIdentifier: nil, xcLanguageSpecificationIdentifier: nil, plistStructureDefinitionIdentifier: nil)
        let sourceFileRef = pbxproj.objects.generateReference(sourceFile, fileName)
        group.children.append(sourceFileRef)
        pbxproj.objects.addObject(sourceFile, reference: sourceFileRef)
        
        guard let resourcesBuildPhase = pbxproj
            .objects.nativeTargets
            .values
            .first(where: {$0.name == target})
            .flatMap({ target -> PBXResourcesBuildPhase? in
                return pbxproj.objects.resourcesBuildPhases.first(where: { target.buildPhases.contains($0.key) })?.value
            }) else { return }
        
        let buildFile = PBXBuildFile(fileRef: sourceFileRef)
        let buildFileRef = pbxproj.objects.generateReference(buildFile, fileName)
        pbxproj.objects.addObject(buildFile, reference: buildFileRef)
        resourcesBuildPhase.files.append(buildFileRef)
    }
}