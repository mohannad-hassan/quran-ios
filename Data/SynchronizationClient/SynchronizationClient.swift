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

    enum Resolution<T> {
        case create(T)
        case delete(T)
        case update(T)
    }

    let localBookmarksPersistence: MutatedPageBookmarkPersistence
    let lastSyncedAt: Date

    init(localBookmarksPersistence: MutatedPageBookmarkPersistence, lastSyncedAt: Date) {
        self.localBookmarksPersistence = localBookmarksPersistence
        self.lastSyncedAt = lastSyncedAt
    }

    func start() async throws {
        let getRequest = GetRemotreUpdateRequest(lastSyncedAt: self.lastSyncedAt)
        let upstreamUpdates = try await getRequest.start()

        let (remoteBookmarks, localBookmarkMutations) = processBookmarks(
            upstream: upstreamUpdates.bookmarksChanges,
            local: try await localBookmarksPersistence.bookmarks()
        )

        let pushRequest = PushLocalUpdateRequest(bookmarkChanges: [/* map localBookmarkMutations */])
        let pushResponse = try await pushRequest.start()

        try await persist(upstreamBookmarkUpdates: remoteBookmarks, and: pushResponse.bookmarksChanges)
    }

    private func persist(upstreamBookmarkUpdates: Resolution<PageBookmarkPersistenceModel>,
                         and pushResult: [RemoteChange<PageBookmarkPersistenceModel>]) async throws {
        try await localBookmarksPersistence.clear()
        /*
         Collect deletions, updates and insertions from both collections.
         Introduce a new function to batch update records in SyncedPageBookmarkPersistence
         */
    }

    private func processBookmarks(upstream: [RemoteChange<PageBookmarkPersistenceModel>],
                                  local: [MutatedPageBookmarkModel]) -> (upstream: Resolution<PageBookmarkPersistenceModel>,
                                                                         local: [MutatedPageBookmarkModel]) {
        fatalError()
    }
}
