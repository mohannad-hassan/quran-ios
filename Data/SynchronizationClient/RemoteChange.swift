//
//  File.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 07/03/2025.
//

import Foundation

struct RemoteChange<T> {
    enum Mutation {
        case created, updated, deleted
    }

    let resourceID: String
    let mutation: Mutation
    let resource: T
}
