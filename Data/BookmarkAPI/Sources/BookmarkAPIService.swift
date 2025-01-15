//
//  BookmarkAPIService.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 15/01/2025.
//

import Foundation

public protocol BookmarkAPIService {

    func createBookmarkRequest() async throws -> CreateBookmarkRequest
}

final class BookmarkAPIServiceImpl: BookmarkAPIService {

    func createBookmarkRequest() async throws -> CreateBookmarkRequest {
        CreateBookmarkRequest()
    }
}
