//
//  File.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 07/03/2025.
//

import Foundation
import PageBookmarkPersistence

struct GetRemotreUpdateRequest {

    // Will need the authorization client here.

    init(lastSyncedAt: Date) {

    }

    struct Response {
        var bookmarksChanges: [RemoteChange<PageBookmarkPersistenceModel>]
    }

    func start() async throws -> Response {
        // API call here.
        fatalError()
    }
}
