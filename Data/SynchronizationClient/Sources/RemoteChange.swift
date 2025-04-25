//
//  File.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 07/03/2025.
//

import Foundation

public enum Mutation {
    case created, updated, deleted
}

struct RemoteChange<T> {

    let resourceID: String
    let mutation: Mutation
    let resource: T
}

public struct Change<T> {
    public let mutation: Mutation
    public let resource: T
    public let resourceID: String
}
