//
//  File.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 05/03/2025.
//

import Foundation
import PageBookmarkPersistence
import MutatedPageBookmarkPersistence
import Combine
import QuranKit

class SynchronizationClient {

    // TODO: Can we avoid PageBookmarkPersistenceModel?
    typealias RemoteBookmarkFetcher = (Date) async throws -> [RemoteChange<PageBookmarkPersistenceModel>]
    typealias LocalBookmarkFetcher = () async throws -> [MutatedPageBookmarkModel]
    typealias LocalBookmarkPusher = ([RemoteChange<PageBookmarkPersistenceModel>]) async throws -> (Date, [RemoteChange<PageBookmarkPersistenceModel>])

    enum Resolution<T> {
        case create(T)
        case delete(T)
        case update(T)
    }

    struct Response {
        let bookmarksMutations: [MutatedPageBookmarkModel]
    }

    let lastSyncedAt: Date

    let fetchRemoteBookmarkUpdates: RemoteBookmarkFetcher
    let fetchLocalBookmarkMutations: LocalBookmarkFetcher
    let pushLocalBookmarkMutations: LocalBookmarkPusher

    init(lastSyncedAt: Date,
         fetchRemoteBookmarkUpdates: @escaping RemoteBookmarkFetcher,
         fetchLocalBookmarkMutations: @escaping LocalBookmarkFetcher,
         pushLocalBookmarkMutations: @escaping LocalBookmarkPusher) {
        self.fetchRemoteBookmarkUpdates = fetchRemoteBookmarkUpdates
        self.fetchLocalBookmarkMutations = fetchLocalBookmarkMutations
        self.lastSyncedAt = lastSyncedAt
        self.pushLocalBookmarkMutations = pushLocalBookmarkMutations
    }

    func execute() async throws -> Response {
        let (remoteBookmarks, local) = processBookmarks(
            // We may cut it short and have the passed closure pass the date.
            upstream: try await fetchRemoteBookmarkUpdates(lastSyncedAt),
            local: try await fetchLocalBookmarkMutations()
        )

        let localChanges = local.map { bookmark in
            let resource = PageBookmarkPersistenceModel(
                remoteID: bookmark.remoteID,
                page: bookmark.page,
                creationDate: bookmark.modificationDate
            )
            return switch bookmark.mutation {
            case .created: RemoteChange<PageBookmarkPersistenceModel>(
                resourceID: resource.remoteID ?? "", mutation: .created, resource: resource
            )
            case .deleted: RemoteChange<PageBookmarkPersistenceModel>(
                resourceID: resource.remoteID ?? "", mutation: .deleted, resource: resource
            )
            }
        }
        let pushedLocal: [MutatedPageBookmarkModel]
        if !localChanges.isEmpty {
            let response = try await pushLocalBookmarkMutations(localChanges)
            pushedLocal = response.1.map {
                // This should be an error.
                .init(remoteID: $0.resource.remoteID ?? "",
                      page: $0.resource.page,
                      modificationDate: $0.resource.creationDate,
                      mutation: $0.mutation == .created ? .created : .deleted)
            }
        }
        else {
            pushedLocal = []
        }

        let result = (remoteBookmarks.map(\.toMutatedModel) + pushedLocal).sorted {
            $0.modificationDate < $1.modificationDate
        }

        return .init(bookmarksMutations: result)
    }

    private func processBookmarks(upstream input: [RemoteChange<PageBookmarkPersistenceModel>],
                                  local: [MutatedPageBookmarkModel]) -> (upstream: [Resolution<PageBookmarkPersistenceModel>],
                                                                         local: [MutatedPageBookmarkModel]) {
        // Will need to coalesce the upstream changes first.
        let upstreamMap = input.reduce(into: Dictionary<String, RemoteChange<PageBookmarkPersistenceModel>>() ) { map, change in
            let id = change.resourceID
            // TODO: add assertions for the correct order of changes.
            if map[id] == nil {
                map[id] = change
            } else {
                map[id] = nil
            }
        }
        let upstream = upstreamMap.values.sorted { $0.resource.creationDate < $1.resource.creationDate }

        // Checking mainly by the page number. If we have the remote ID persisted locally, then it should
        // come up when filtering by the page number.
        let upstreamPages = upstream.map { $0.resource.page }
        let localPages = local.map { $0.page }
        let resourcesModifiedInBoth: [Int] = upstreamPages.filter(localPages.contains)

        var filteredOutLocal: [MutatedPageBookmarkModel] = []
        for page in resourcesModifiedInBoth {
            let upstreamChange = upstream.filter { $0.resource.page == page }
            let localChange = local.filter { $0.page == page }

            if let localDeletion = localChange.first(where: { $0.mutation == .deleted }),
               upstreamChange.first(where: { $0.mutation == .deleted }) != nil {
                filteredOutLocal.append(localDeletion)
            }
            if let localCreation = localChange.first(where: { $0.mutation == .created }),
               upstreamChange.first(where: { $0.mutation == .created }) != nil {
                filteredOutLocal.append(localCreation)
            }
        }

        return (upstream: upstream.map(\.toResolution), local: local.filter { !filteredOutLocal.contains($0) })
    }
}

extension SynchronizationClient.Resolution where T == PageBookmarkPersistenceModel {

    var toMutatedModel: MutatedPageBookmarkModel {
        let mutation: MutatedPageBookmarkModel.Mutation
        let resource: PageBookmarkPersistenceModel
        switch self {
        case .create(let model):
            mutation = .created
            resource = model
        case .delete(let model):
            mutation = .deleted
            resource = model
        case .update:
            fatalError()
        }

        return .init(
            remoteID: resource.remoteID,
            page: resource.page,
            modificationDate: resource.creationDate,
            mutation: mutation
        )
    }
}


extension RemoteChange<PageBookmarkPersistenceModel> {
    var toResolution: SynchronizationClient.Resolution<PageBookmarkPersistenceModel> {
        switch mutation {
        case .created:
            return .create(resource)
        case .deleted:
            return .delete(resource)
        case .updated:
            fatalError()
        }
    }
}
