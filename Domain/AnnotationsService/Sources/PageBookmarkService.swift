//
//  PageBookmarkService.swift
//  Quran
//
//  Created by Mohamed Afifi on 2023-03-05.
//  Copyright © 2023 Quran.com. All rights reserved.
//

import BookmarkAPI
import Combine
import Foundation
import PageBookmarkPersistence
import QuranAnnotations
import QuranKit
import VLogging

public struct PageBookmarkService {
    // MARK: Lifecycle

    public init(
        persistence: PageBookmarkPersistence,
        apiService: BookmarkAPIService
    ) {
        self.persistence = persistence
        self.apiService = apiService
    }

    // MARK: Public

    public func pageBookmarks(quran: Quran) -> AnyPublisher<[PageBookmark], Never> {
        persistence.pageBookmarks()
            .map { bookmarks in bookmarks.map { PageBookmark(quran: quran, $0) } }
            .eraseToAnyPublisher()
    }

    public func insertPageBookmark(_ page: Page) async throws {
        let committedPage: Page = if let updatedPage = try await performInsertionAPI(page) {
            updatedPage
        } else {
            page
        }
        try await persistence.insertPageBookmark(committedPage.pageNumber)
    }

    private func performInsertionAPI(_ page: Page) async throws -> Page? {
        do {
            // TODO: Hardfix "1" for now. The models don't reflect the BE IDs of the mushafs.
            guard let request = try await apiService.createBookmarkRequest(
                forPageNumber: page.pageNumber,
                mushafID: "1"
            ) else {
                return nil
            }
            logger.info("Bookmark request for page \(page.pageNumber) is a success.")
            if let resultPageNumber = try await request.execute() {
                return Page(quran: page.quran, pageNumber: resultPageNumber)
            } else {
                return page
            }
        } catch {
            logger.error("Failed to create bookmark: \(error)")
            return nil
        }
    }

    public func removePageBookmark(_ page: Page) async throws {
        try await persistence.removePageBookmark(page.pageNumber)
    }

    // MARK: Internal

    let persistence: PageBookmarkPersistence
    let apiService: BookmarkAPIService
}

private extension PageBookmark {
    init(quran: Quran, _ other: PageBookmarkPersistenceModel) {
        self.init(
            page: Page(quran: quran, pageNumber: Int(other.page))!,
            creationDate: other.creationDate
        )
    }
}
