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

    // TODO: Can we get rid of using PageBookmarkPersistenceModel?
    typealias RemoteBookmarkFetcher = (Date) async throws -> [RemoteChange<PageBookmarkPersistenceModel>]
    typealias LocalBookmarkFetcher = () async throws -> [MutatedPageBookmarkModel]

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


    init(lastSyncedAt: Date,
        fetchRemoteBookmarkUpdates: @escaping RemoteBookmarkFetcher,
         fetchLocalBookmarkMutations: @escaping LocalBookmarkFetcher) {
        self.fetchRemoteBookmarkUpdates = fetchRemoteBookmarkUpdates
        self.fetchLocalBookmarkMutations = fetchLocalBookmarkMutations
        self.lastSyncedAt = lastSyncedAt
    }

    func execute() async throws -> Response {
        let (remoteBookmarks, _) = processBookmarks(
            // We may cut it short and have the passed closure pass the date.
            upstream: try await fetchRemoteBookmarkUpdates(lastSyncedAt),
            local: try await fetchLocalBookmarkMutations()
        )

//        let pushRequest = PushLocalUpdateRequest(bookmarkChanges: [/* map localBookmarkMutations */])
//        let pushResponse = try await pushRequest.start()


        return .init(bookmarksMutations: remoteBookmarks.map(\.toMutatedModel))
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
//        let upstreamPages = upstream.map { $0.resource.page }
//        let localPages = local.map { $0.page }
//        let resourcesModifiedInBoth: [Int] = upstreamPages.filter(localPages.contains)
//
//        for page in resourcesModifiedInBoth {
//            let upstreamChange = upstream.first { $0.resource.page == page }!
//
//        }

        return (upstream: upstream.map(\.toResolution), local: [])
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
