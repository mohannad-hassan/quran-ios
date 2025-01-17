//
//  BookmarkAPIService.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 15/01/2025.
//

import AuthenticationClient
import Foundation
import QuranAnnotations
import VLogging

public protocol BookmarkAPIService {
    func createBookmarkRequest(forPageNumber pageNumber: Int, mushafID: String) async throws -> CreateBookmarkRequest?
}

public final class BookmarkAPIServiceImpl: BookmarkAPIService {
    private let authenticationClient: AuthenticationClient?

    public init(authenticationClient: AuthenticationClient?) {
        self.authenticationClient = authenticationClient
    }

    public func createBookmarkRequest(
        forPageNumber pageNumber: Int,
        mushafID: String
    ) async throws -> CreateBookmarkRequest? {
        guard let authenticationClient else {
            logger.info("Bookmarks APIs. No authentication client found")
            return nil
        }
        guard await authenticationClient.authenticationState == .authenticated else {
            logger.info("Bookmarks APIs. App is not authenticated.")
            return nil
        }

        let request = CreateBookmarkRequest(
            pageNumber: pageNumber,
            mushafID: mushafID,
            networkManager: .init(
                authenticationClient: authenticationClient,
                session: URLSession.shared
            )
        )

        return request
    }
}

class AuthenticatedNetworkManager {
    private let baseURL = "https://staging-oauth2.quran.foundation/auth/v1"
    private let authenticationClient: AuthenticationClient
    private let session: URLSession

    init(authenticationClient: AuthenticationClient, session: URLSession) {
        self.authenticationClient = authenticationClient
        self.session = session
    }

    func request(path: String, method: String = "GET", payload: Data? = nil) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpBody = payload
        request.httpMethod = method
        request = try await authenticationClient.authenticate(request: request)
        return try await session.data(for: request)
    }
}
