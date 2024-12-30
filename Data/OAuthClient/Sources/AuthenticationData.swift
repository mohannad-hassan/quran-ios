//
//  File.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 27/12/2024.
//

import Foundation
import AppAuth
import Combine
import VLogging

enum AuthenticationStateError: Error {
    case failedToRefreshTokens(Error?)
}

class AuthenticationData: NSObject, Codable {

    var stateChangedPublisher: AnyPublisher<Void, Never> { fatalError() }

    var isAuthorized: Bool {
        fatalError()
    }

    func getFreshTokens() async throws -> String {
        fatalError()
    }

    override init() { }

    required init(from decoder: any Decoder) throws {
        fatalError()
    }
}

class AppAuthAuthenticationData: AuthenticationData {
    private enum CodingKeys: String, CodingKey {
        case state
    }

    private let stateChangedSubject: PassthroughSubject<Void, Never> = .init()
    override var stateChangedPublisher: AnyPublisher<Void, Never> {
        stateChangedSubject.eraseToAnyPublisher()
    }

    private var state: OIDAuthState? {
        didSet {
            stateChangedSubject.send()
        }
    }

    override var isAuthorized: Bool {
        state?.isAuthorized ?? false
    }

    init(state: OIDAuthState? = nil) {
        self.state = state
        super.init()
        state?.stateChangeDelegate = self
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let data = try container.decodeIfPresent(Data.self, forKey: .state) {
            self.state = try NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data)
        }
        super.init()
        state?.stateChangeDelegate = self
    }

    override func encode(to encoder: any Encoder) throws {
        var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
        if let state {
            let data = try NSKeyedArchiver.archivedData(withRootObject: state, requiringSecureCoding: true)
            try container.encode(data, forKey: .state)
        }
        else {
            try container.encodeNil(forKey: .state)
        }
    }

    override func getFreshTokens() async throws -> String {
        guard let state = state else {
            // TODO: We need to define proper errors here.
            throw NSError()
        }
        return try await withCheckedThrowingContinuation { continuation in
            state.performAction { accessToken, clientID, error in
                guard error == nil else {
                    logger.error("Failed to refresh tokens: \(error!)")
                    continuation.resume(throwing: AuthenticationStateError.failedToRefreshTokens(error))
                    return
                }
                guard let accessToken = accessToken else {
                    logger.error("Failed to refresh tokens: No access token returned. An unexpected situation.")
                    continuation.resume(throwing: AuthenticationStateError.failedToRefreshTokens(nil))
                    return
                }
                continuation.resume(returning: accessToken)
            }
        }
    }
}

extension AppAuthAuthenticationData: OIDAuthStateChangeDelegate {

    func didChange(_ state: OIDAuthState) {
        self.stateChangedSubject.send()
    }
}