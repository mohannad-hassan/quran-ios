//
//  File.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 07/03/2025.
//

import Foundation
import PageBookmarkPersistence

// We may need to convert this into an actor. This will probably be the main entry point of the API.
public class SyncrhonizationManager {

    private let scheduler: SerializationScheduler
    private let bookmarksPersistence: PageBookmarkPersistence
    private let syncInfoPersistence: SyncInfoPersistence

    init(scheduler: SerializationScheduler, bookmarksPersistence: PageBookmarkPersistence, syncInfoPersistence: SyncInfoPersistence) {
        self.scheduler = scheduler
        self.bookmarksPersistence = bookmarksPersistence
        self.syncInfoPersistence = syncInfoPersistence
    }

    func setup() {
        let schedulerCancellable = scheduler.invokationSignal.sink {
            Task { await self.sync() }
        }

//        let bookmarksCancellable = bookmarksPersistence.modificationSignal.sink {
//            scheduler.localDataModified()
//        }
    }

    private func sync() async {
        // protect access and mutual exclusion and stuff
        do {
            let client: SynchronizationClient! = nil
            try await client.execute()
            // Expected to get a Date value here.
        } catch {

        }
    }
}

extension SyncrhonizationManager {
    // If configurations for a model are not set, then it's assumed to be disabled.
    static func instance(bookmarksConf: BookmarksConfiguration?,
                         notesConf: NotesConfiguration?) -> SyncrhonizationManager {
        fatalError()
    }
}

public struct NotesConfiguration {

}
