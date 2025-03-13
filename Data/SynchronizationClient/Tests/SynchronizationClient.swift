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
            pushLocalBookmarkMutations: {_ in (Date(), []) }
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
            pushLocalBookmarkMutations: {_ in (Date(), []) }
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
        let page100_remoteID = "Y1"

        var pushLocalBookmarksExpectation: XCTestExpectation!
        sut = SynchronizationClient(
            lastSyncedAt: .distantPast,
            fetchRemoteBookmarkUpdates: { _ in remoteChanges},
            fetchLocalBookmarkMutations: { localChanges },
            pushLocalBookmarkMutations: { pushed in
                pushLocalBookmarksExpectation.fulfill()
                XCTAssertEqual(pushed.map(\.resource.page), localChanges.map(\.page))
                XCTAssertEqual(pushed.map(\.mutation), [.created, .deleted], "Should have the correct mutation.")
                return (Date(), [
                    RemoteChange(resourceID: page100_remoteID,
                                 mutation: .created,
                                 resource: PageBookmarkPersistenceModel(remoteID: page100_remoteID,
                                                                        page: 100,
                                                                        creationDate: .init(timeIntervalSince1970: 50))),
                    RemoteChange(resourceID: "Z1",
                                 mutation: .deleted,
                                 resource: .init(remoteID: "Z1",
                                                 page: 99,
                                                 creationDate: .init(timeIntervalSince1970: 45))),
                ])
            }
        )

        pushLocalBookmarksExpectation = expectation(description: "Expected local bookmarks to be pushed.")

        let result = try await sut.execute()
        let expected: [MutatedPageBookmarkModel] = [
            .init(remoteID: a1.remoteID, page: a1.page, modificationDate: a1.creationDate, mutation: .created),
            .init(remoteID: a2.remoteID, page: a2.page, modificationDate: a2.creationDate, mutation: .deleted),
            .init(remoteID: page100_remoteID, page: 100, modificationDate: .init(timeIntervalSince1970: 50), mutation: .created),
            .init(remoteID: "Z1", page: 99, modificationDate: .init(timeIntervalSince1970: 45), mutation: .deleted),
        ]

        XCTAssertEqual(expected.map(\.page), result.bookmarksMutations.map(\.page),
                       "Match pages")
        XCTAssertEqual(expected.map(\.remoteID), result.bookmarksMutations.map(\.remoteID),
                       "Match remote IDs")
        XCTAssertEqual(expected.map(\.mutation), result.bookmarksMutations.map(\.mutation),
                       "Match mutation types.")

        await fulfillment(of: [pushLocalBookmarksExpectation], timeout: 2)
    }

    func testSameBookmarkDeletedOnBoth() async throws {
        let a1 = PageBookmarkPersistenceModel(remoteID: "A1", page: 10, creationDate: .init(timeIntervalSince1970: 40))
        let remoteChanges: [RemoteChange<PageBookmarkPersistenceModel>] = [
            .init(
                resourceID: "A1",
                mutation: .deleted,
                resource: a1
            ),
        ]
        let localChanges: [MutatedPageBookmarkModel] = [
            .init(remoteID: "A1", page: 10, modificationDate: .init(timeIntervalSince1970: 50), mutation: .deleted),
        ]

        sut = SynchronizationClient(
            lastSyncedAt: .distantPast,
            fetchRemoteBookmarkUpdates: { _ in remoteChanges},
            fetchLocalBookmarkMutations: { localChanges },
            pushLocalBookmarkMutations: { pushed in
                XCTFail("Expected to treat the local changes as redundant. Should not push anything.")
                return (Date(), [])
            }
        )

        let result = try await sut.execute()
        let expected: [MutatedPageBookmarkModel] = [
            .init(remoteID: a1.remoteID, page: a1.page, modificationDate: a1.creationDate, mutation: .deleted),
        ]
        // The modification date is irrelevant in this case.
        XCTAssertEqual(expected.map(\.page), result.bookmarksMutations.map(\.page), "Match pages")
        XCTAssertEqual(expected.map(\.remoteID), result.bookmarksMutations.map(\.remoteID), "Match remote IDs")
        XCTAssertEqual(expected.map(\.mutation), result.bookmarksMutations.map(\.mutation), "Match mutation")
    }

    func testAddedBookmarkForSamePageOnBoth() async throws {
        let a1 = PageBookmarkPersistenceModel(remoteID: "A1", page: 10, creationDate: .init(timeIntervalSince1970: 40))
        let remoteChanges: [RemoteChange<PageBookmarkPersistenceModel>] = [
            .init(
                resourceID: "A1",
                mutation: .created,
                resource: a1
            ),
        ]
        let localChanges: [MutatedPageBookmarkModel] = [
            .init(remoteID: nil, page: 10, modificationDate: .init(timeIntervalSince1970: 50), mutation: .created),
        ]

        sut = SynchronizationClient(
            lastSyncedAt: .distantPast,
            fetchRemoteBookmarkUpdates: { _ in remoteChanges},
            fetchLocalBookmarkMutations: { localChanges },
            pushLocalBookmarkMutations: { pushed in
                XCTFail("Expected to treat the local changes as redundant. Should not push anything.")
                return (Date(), [])
            }
        )

        let result = try await sut.execute()
        let expected: [MutatedPageBookmarkModel] = [
            .init(remoteID: a1.remoteID, page: a1.page, modificationDate: a1.creationDate, mutation: .created),
        ]
        // Ideally, this should favor the local change since it's more recent. The actions of which
        // would be to delete the remote bookmark and create a new one.
        // To simplify things, we'll just keep the remote change.
        XCTAssertEqual(expected, result.bookmarksMutations, "Expected to keep the remote change.")
    }

    func test_deletedLocallyRemotely_createdLocally() async throws {
        let a1 = PageBookmarkPersistenceModel(remoteID: "A1", page: 10, creationDate: .init(timeIntervalSince1970: 40))
        let remoteChanges: [RemoteChange<PageBookmarkPersistenceModel>] = [
            .init(
                resourceID: "A1",
                mutation: .deleted,
                resource: a1
            ),
        ]
        let localChanges: [MutatedPageBookmarkModel] = [
            .init(remoteID: "A1", page: 10, modificationDate: .init(timeIntervalSince1970: 50), mutation: .deleted),
            .init(remoteID: nil, page: 10, modificationDate: .init(timeIntervalSince1970: 60), mutation: .created),
        ]

        let newRemoteID = "B1"

        var localChangesExpectation: XCTestExpectation!
        var expectedLocalChangesToPush: [MutatedPageBookmarkModel] = []
        sut = SynchronizationClient(
            lastSyncedAt: .distantPast,
            fetchRemoteBookmarkUpdates: { _ in remoteChanges},
            fetchLocalBookmarkMutations: { localChanges },
            pushLocalBookmarkMutations: { pushed in
                localChangesExpectation.fulfill()
                XCTAssertEqual(expectedLocalChangesToPush.map(\.page), pushed.map(\.resource).map(\.page))
                XCTAssertEqual(expectedLocalChangesToPush.map(\.remoteID), pushed.map(\.resource).map(\.remoteID))
                //                XCTAssertEqual(expectedLocalChangesToPush.map(\.mutation), pushed.map(\.mutation))
                return (Date(),
                        [RemoteChange.init(resourceID: newRemoteID,
                                           mutation: .created,
                                           resource: .init(remoteID: newRemoteID,
                                                           page: 10,
                                                           creationDate: .init(timeIntervalSince1970: 60)))]
                )
            }
        )
        localChangesExpectation = expectation(description: "Local changes should be pushed.")
        expectedLocalChangesToPush = [
            localChanges[1],
        ]
        let result = try await sut.execute()
        let expected: [MutatedPageBookmarkModel] = [
            // The deletion's timestamp is irrelevant here.
            .init(remoteID: a1.remoteID, page: a1.page, modificationDate: a1.creationDate, mutation: .deleted),
            .init(remoteID: newRemoteID, page: 10, modificationDate: localChanges[1].modificationDate, mutation: .created),
        ]
        XCTAssertEqual(result.bookmarksMutations, expected)

        await fulfillment(of: [localChangesExpectation], timeout: 2)
    }

    func test_deletedLocallyRemotely_createdRemotely() async throws {
        let a1 = PageBookmarkPersistenceModel(remoteID: "A1", page: 10, creationDate: .init(timeIntervalSince1970: 40))
        let b1 = PageBookmarkPersistenceModel(remoteID: "B1", page: 10, creationDate: .init(timeIntervalSince1970: 60))
        let remoteChanges: [RemoteChange<PageBookmarkPersistenceModel>] = [
            .init(
                resourceID: "A1",
                mutation: .deleted,
                resource: a1
            ),
            .init(
                resourceID: "B1",
                mutation: .created,
                resource: b1
            ),
        ]
        let localChanges: [MutatedPageBookmarkModel] = [
            .init(remoteID: "A1", page: 10, modificationDate: .init(timeIntervalSince1970: 50), mutation: .deleted),
        ]

        sut = SynchronizationClient(
            lastSyncedAt: .distantPast,
            fetchRemoteBookmarkUpdates: { _ in remoteChanges},
            fetchLocalBookmarkMutations: { localChanges },
            pushLocalBookmarkMutations: { pushed in
                XCTFail("Expected to treat the local changes as redundant. Should not push anything.")
                return (Date(), [])
            }
        )

        let result = try await sut.execute()
        let expected: [MutatedPageBookmarkModel] = [
            // The deletion's timestamp is irrelevant here.
            .init(remoteID: a1.remoteID, page: a1.page, modificationDate: a1.creationDate, mutation: .deleted),
            .init(remoteID: b1.remoteID, page: b1.page, modificationDate: b1.creationDate, mutation: .created),
        ]
        XCTAssertEqual(result.bookmarksMutations, expected)
    }

    func test_deletedCreatedOnBoth() async throws {
        let a1 = PageBookmarkPersistenceModel(remoteID: "A1", page: 10, creationDate: .init(timeIntervalSince1970: 40))
        let b1 = PageBookmarkPersistenceModel(remoteID: "B1", page: 10, creationDate: .init(timeIntervalSince1970: 60))
        let remoteChanges: [RemoteChange<PageBookmarkPersistenceModel>] = [
            .init(
                resourceID: "A1",
                mutation: .deleted,
                resource: a1
            ),
            .init(
                resourceID: "B1",
                mutation: .created,
                resource: b1
            ),
        ]
        let localChanges: [MutatedPageBookmarkModel] = [
            .init(remoteID: "A1", page: 10, modificationDate: .init(timeIntervalSince1970: 50), mutation: .deleted),
            .init(remoteID: nil, page: 10, modificationDate: .init(timeIntervalSince1970: 55), mutation: .created),
        ]

        sut = SynchronizationClient(
            lastSyncedAt: .distantPast,
            fetchRemoteBookmarkUpdates: { _ in remoteChanges},
            fetchLocalBookmarkMutations: { localChanges },
            pushLocalBookmarkMutations: { pushed in
                XCTFail("Expected to treat the local changes as redundant. Should not push anything.")
                return (Date(), [])
            }
        )

        let result = try await sut.execute()
        let expected: [MutatedPageBookmarkModel] = [
            // The deletion's timestamp is irrelevant here.
            .init(remoteID: a1.remoteID, page: a1.page, modificationDate: a1.creationDate, mutation: .deleted),
            .init(remoteID: b1.remoteID, page: b1.page, modificationDate: b1.creationDate, mutation: .created),
        ]
        XCTAssertEqual(result.bookmarksMutations, expected)
    }
}
