//
//  File.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 15/01/2025.
//

import Foundation
import QuranAnnotations

struct BookmarkAPIJSON: Decodable {
    let id: String
    let createdAt: Date
    let type: String
    let key: Int?
    let verseNumber: Int?
    let group: String?
}

// TODO: Do this
enum TODOErrors: Error {
    case someError
}

public struct CreateBookmarkRequest {
    struct RequestBody: Encodable {
        let key: Int
        let type: String = "page"
        let mushaf: String
    }

    private let networkManager: AuthenticatedNetworkManager

    private let requestBody: RequestBody

    struct Response: Decodable {
        let success: Bool
        let bookmark: BookmarkAPIJSON
    }

    init(pageNumber: Int,
         mushafID: String,
         networkManager: AuthenticatedNetworkManager) {
        self.networkManager = networkManager
        self.requestBody = RequestBody(key: pageNumber, mushaf: mushafID)
    }

    // Simplify logic for now; return the page number.
    // However, it will be a question to ponder. Should the APIs in general return a model,
    // or just some primitves and leave the details of model management to the domain services?
    //

    public func execute() async throws -> Int? {
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(requestBody)
        let (data, response) = try await networkManager.request(path: "/bookmarks",
                                                                method: "POST",
                                                                payload: requestData)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw TODOErrors.someError
        }

        let responseObject = try JSONDecoder().decode(Response.self, from: data)
        return responseObject.bookmark.key
    }
}
