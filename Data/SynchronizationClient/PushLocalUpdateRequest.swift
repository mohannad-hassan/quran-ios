//
//  File.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 07/03/2025.
//

import Foundation
import PageBookmarkPersistence

struct PushLocalUpdateRequest {

    // TODO: we may need a different model than PageBookmarkPersistenceModel for this.
    init(bookmarkChanges: [RemoteChange<PageBookmarkPersistenceModel>]) {

    }

    // Will need the authorization client here.

    struct Response {
        var bookmarksChanges: [RemoteChange<PageBookmarkPersistenceModel>]
    }

    func start() async throws -> Response {
        // API call here.
        fatalError()
    }
}
