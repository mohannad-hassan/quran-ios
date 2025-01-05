//
//  AuthentincationClientImpl.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 23/12/2024.
//

import AppAuth
import Combine
import Foundation
import UIKit
import VLogging

final class AuthenticationClientImpl: AuthenticationClient {
    // MARK: Lifecycle

    init(configurations: OAuthAppConfiguration?, caller: OAuthCaller, persistence: Persistence) {
        self.caller = caller
        self.persistence = persistence
        appConfiguration = configurations
    }

    // MARK: Public

    public var authenticationState: AuthenticationState {
        guard appConfiguration != nil else {
            return .notAvailable
        }
        return state?.isAuthorized == true ? .authenticated : .notAuthenticated
    }

    public func login(on viewController: UIViewController) async throws {
        do {
            try persistence.clear()
            logger.info("Cleared previous authentication state before login")
        } catch {
            // If persisting the new state works, this error should be of little concern.
            logger.warning("Failed to clear previous authentication state before login: \(error)")
        }

        guard let configuration = appConfiguration else {
            logger.error("login invoked without OAuth client configurations being set")
            throw AuthenticationClientError.oauthClientHasNotBeenSet
        }

        let state = try await caller.login(using: configuration, on: viewController)
        self.state = state
        logger.info("login succeeded with state. isAuthorized: \(state.isAuthorized)")
        persist(state: state)
    }

    public func restoreState() async throws -> Bool {
        guard appConfiguration != nil else {
            logger.error("restoreState invoked without OAuth client configurations being set")
            throw AuthenticationClientError.oauthClientHasNotBeenSet
        }
        guard let state = try persistence.retrieve() else {
            logger.info("No previous authentication state found")
            return false
        }
        // TODO: Called for the side effects!
        _ = try await state.getFreshTokens()
        self.state = state
        logger.info("Restored previous authentication state. isAuthorized: \(state.isAuthorized)")
        return state.isAuthorized
    }

    public func authenticate(request: URLRequest) async throws -> URLRequest {
        guard let configuration = appConfiguration else {
            logger.error("authenticate invoked without OAuth client configurations being set")
            throw AuthenticationClientError.oauthClientHasNotBeenSet
        }
        guard authenticationState == .authenticated, let state else {
            logger.error("authenticate invoked without client being authenticated")
            throw AuthenticationClientError.clientIsNotAuthenticated
        }
        let token = try await state.getFreshTokens()
        var request = request
        request.setValue(token, forHTTPHeaderField: "x-auth-token")
        request.setValue(configuration.clientID, forHTTPHeaderField: "x-client-id")
        return request
    }

    // MARK: Private

    private let caller: OAuthCaller
    private let persistence: Persistence

    private var stateChangedCancellable: AnyCancellable?

    private var appConfiguration: OAuthAppConfiguration?

    private var state: AuthenticationData? {
        didSet {
            guard let state else { return }
            stateChangedCancellable = state.stateChangedPublisher.sink { [weak self] _ in
                self?.persist(state: state)
            }
        }
    }

    private func persist(state: AuthenticationData) {
        do {
            try persistence.persist(state: state)
        } catch {
            // If this happens, the state will not nullified so to keep the current session usable
            // for the user. As for now, no workaround is in hand.
            logger.error("Failed to persist authentication state. No workaround in hand.: \(error)")
        }
    }
}

extension AuthenticationClientImpl {
    public convenience init(configurations: OAuthAppConfiguration?) {
        self.init(
            configurations: configurations,
            caller: AppAuthCaller(),
            persistence: KeychainPersistence()
        )
    }
}
