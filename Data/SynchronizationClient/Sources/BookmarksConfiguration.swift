//
//  File.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 16/04/2025.
//

import Foundation

/// BookmarksSyncrhonizationConfiguration
public struct BookmarksConfiguration {
    public enum EnabledType {
        case ayah, page, juz, sura
    }
    /// Fetches the local mutations from the given date.
    public typealias LocalMutationsFetcher = (Date) async throws -> [Change<Bookmark>]

    /// Called on success to persist the resolved changed in the DB.
    public typealias ResultFinalizer = (Date, [Change<Bookmark>]) async throws -> Void

    public init(enabledTypes: [EnabledType],
                fetcher: @escaping LocalMutationsFetcher,
                finalizer: @escaping ResultFinalizer) { }
}

public struct Bookmark {
    public enum BookmarkType {
        case sura(suraNumber: Int)
        case juz(juzNumber: Int)
        case page(pageNumber: Int)
        case ayah(suraNumber: Int, ayahNumber: Int)
    }

    public let id: String
    public let type: BookmarkType
    public let modificationDate: Date
}
