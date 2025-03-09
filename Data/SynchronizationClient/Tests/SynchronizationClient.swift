//
//  SynchronizationClient.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 07/03/2025.
//

import XCTest
import PageBookmarkPersistence
import MutatedPageBookmarkPersistence
@testable import SynchronizationClient

final class SynchronizationClientTests: XCTestCase {

    var sut: SynchronizationClient!

    func testOnlyRemoteChanges() async throws {
        let remoteChanges: [RemoteChange<PageBookmarkPersistenceModel>] = [
            .init(
                resourceID: "A1",
                mutation: .created,
                resource: PageBookmarkPersistenceModel(remoteID: "A1", page: 10, creationDate: .init(timeIntervalSince1970: 10))
            ),
            .init(
                resourceID: "A2",
                mutation: .deleted,
                resource: PageBookmarkPersistenceModel(remoteID: "A2", page: 12, creationDate: .init(timeIntervalSince1970: 100))
            ),
            .init(
                resourceID: "B1",
                mutation: .created,
                resource: PageBookmarkPersistenceModel(remoteID: "B1", page: 15, creationDate: .init(timeIntervalSince1970: 200))
            ),
        ]

        sut = SynchronizationClient(
            lastSyncedAt: .distantPast,
            fetchRemoteBookmarkUpdates: { _ in remoteChanges},
            fetchLocalBookmarkMutations: { [] },
            pushLocalBookmarkMutations: {_ in Date() }
        )

        let result = try await sut.execute()
        let expected: [MutatedPageBookmarkModel] = remoteChanges.map { change in
            MutatedPageBookmarkModel(
                remoteID: change.resourceID,
                page: change.resource.page,
                modificationDate: change.resource.creationDate,
                mutation: change.mutation == .created ? .created : .deleted
            )
        }

        XCTAssertEqual(expected.map(\.page), result.bookmarksMutations.map(\.page),
                       "Match pages")
        XCTAssertEqual(expected.map(\.remoteID), result.bookmarksMutations.map(\.remoteID),
                       "Match remote IDs")
        XCTAssertEqual(expected.map(\.mutation), result.bookmarksMutations.map(\.mutation),
                       "Match mutation types.")
    }

    func testCoalescingRemoteChanges() async throws {
        let a1 = PageBookmarkPersistenceModel(remoteID: "A1", page: 10, creationDate: .init(timeIntervalSince1970: 10))
        let a2 = PageBookmarkPersistenceModel(remoteID: "A2", page: 12, creationDate: .init(timeIntervalSince1970: 100))
        let b1 = PageBookmarkPersistenceModel(remoteID: "B1", page: 15, creationDate: .init(timeIntervalSince1970: 200))
        let remoteChanges: [RemoteChange<PageBookmarkPersistenceModel>] = [
            .init(
                resourceID: "A1",
                mutation: .created,
                resource: a1
            ),
            .init(
                resourceID: "A2",
                mutation: .deleted,
                resource: a2
            ),
            .init(
                resourceID: "B1",
                mutation: .created,
                resource: b1
            ),
            .init(
                resourceID: "A1",
                mutation: .deleted,
                resource: a1
            ),
        ]

        sut = SynchronizationClient(
            lastSyncedAt: .distantPast,
            fetchRemoteBookmarkUpdates: { _ in remoteChanges},
            fetchLocalBookmarkMutations: { [] },
            pushLocalBookmarkMutations: {_ in Date() }
        )

        let result = try await sut.execute()
        let expected: [MutatedPageBookmarkModel] = [
            .init(remoteID: a2.remoteID, page: a2.page, modificationDate: a2.creationDate, mutation: .deleted),
            .init(remoteID: b1.remoteID, page: b1.page, modificationDate: b1.creationDate, mutation: .created),
        ]

        XCTAssertEqual(expected.map(\.page), result.bookmarksMutations.map(\.page),
                       "Match pages")
        XCTAssertEqual(expected.map(\.remoteID), result.bookmarksMutations.map(\.remoteID),
                       "Match remote IDs")
        XCTAssertEqual(expected.map(\.mutation), result.bookmarksMutations.map(\.mutation),
                       "Match mutation types.")
    }

    func testUncollidingLocalChanges() async throws {
        let a1 = PageBookmarkPersistenceModel(remoteID: "A1", page: 10, creationDate: .init(timeIntervalSince1970: 10))
        let a2 = PageBookmarkPersistenceModel(remoteID: "A2", page: 12, creationDate: .init(timeIntervalSince1970: 100))
        let remoteChanges: [RemoteChange<PageBookmarkPersistenceModel>] = [
            .init(
                resourceID: "A1",
                mutation: .created,
                resource: a1
            ),
            .init(
                resourceID: "A2",
                mutation: .deleted,
                resource: a2
            ),
        ]
        let localChanges: [MutatedPageBookmarkModel] = [
            .init(remoteID: nil, page: 100, modificationDate: .init(timeIntervalSince1970: 50), mutation: .created),
            .init(remoteID: "Z1", page: 99, modificationDate: .init(timeIntervalSince1970: 45), mutation: .deleted),
        ]

        var pushLocalBookmarksExpectation: XCTestExpectation!
        sut = SynchronizationClient(
            lastSyncedAt: .distantPast,
            fetchRemoteBookmarkUpdates: { _ in remoteChanges},
            fetchLocalBookmarkMutations: { localChanges },
            pushLocalBookmarkMutations: { pushed in
                pushLocalBookmarksExpectation.fulfill()
                XCTAssertEqual(pushed.map(\.resource.page), localChanges.map(\.page))
                XCTAssertEqual(pushed.map(\.mutation), [.created, .deleted], "Should have the correct mutation.")
                return Date()
            }
        )

        pushLocalBookmarksExpectation = expectation(description: "Expected local bookmarks to be pushed.")

        let result = try await sut.execute()
        let expected: [MutatedPageBookmarkModel] = [
            .init(remoteID: a1.remoteID, page: a1.page, modificationDate: a1.creationDate, mutation: .created),
            .init(remoteID: a2.remoteID, page: a2.page, modificationDate: a2.creationDate, mutation: .deleted),
        ] + localChanges

        XCTAssertEqual(expected.map(\.page), result.bookmarksMutations.map(\.page),
                       "Match pages")
        XCTAssertEqual(expected.map(\.remoteID), result.bookmarksMutations.map(\.remoteID),
                       "Match remote IDs")
        XCTAssertEqual(expected.map(\.mutation), result.bookmarksMutations.map(\.mutation),
                       "Match mutation types.")

        await fulfillment(of: [pushLocalBookmarksExpectation], timeout: 2)
    }
}
