//
//  File.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 26/12/2024.
//

import Foundation
import AppAuth
import VLogging

final class AppAuthCaller: OAuthCaller {

    func login(using configuration: OAuthAppConfiguration, on viewController: UIViewController) async throws -> OIDAuthState {
        // Quran.com relies on dicovering the service configuration from the issuer,
        // and not using a static configuration.
        let serviceConfiguration = try await discoverConfiguration(forIssuer: configuration.authorizationIssuerURL)
        return try await login(using: configuration, on: viewController)
    }

    // MARK: Private

    // Needed mainly for retention.
    private var authFlow: (any OIDExternalUserAgentSession)?
    private var appConfiguration: OAuthAppConfiguration?

    // MARK: - Authenication Flow

    private func discoverConfiguration(forIssuer issuer: URL) async throws -> OIDServiceConfiguration {
        logger.info("Discovering configuration for OAuth")
        return try await withCheckedThrowingContinuation { continuation in
            OIDAuthorizationService
                .discoverConfiguration(forIssuer: issuer) { configuration, error in
                    guard error == nil else {
                        logger.error("Error fetching OAuth configuration: \(error!)")
                        continuation.resume(throwing: OAuthClientError.errorFetchingConfiguration(error))
                        return
                    }
                    guard let configuration else {
                        // This should not happen
                        logger.error("Error fetching OAuth configuration: no configuration was loaded. An unexpected situtation.")
                        continuation.resume(throwing: OAuthClientError.errorFetchingConfiguration(nil))
                        return
                    }
                    logger.info("OAuth configuration fetched successfully")
                    continuation.resume(returning: configuration)
                }
        }
    }

    private func login(
        withConfiguration configuration: OIDServiceConfiguration,
        appConfiguration: OAuthAppConfiguration,
        on viewController: UIViewController
    ) async throws -> OIDAuthState {
        let scopes = [OIDScopeOpenID, OIDScopeProfile] + appConfiguration.scopes
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: appConfiguration.clientID,
            clientSecret: nil,
            scopes: scopes,
            redirectURL: appConfiguration.redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: [:]
        )

        logger.info("Starting OAuth flow")
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.authFlow = OIDAuthState.authState(
                    byPresenting: request,
                    presenting: viewController
                ) { [weak self] state, error in
                    self?.authFlow = nil
                    guard error == nil else {
                        logger.error("Error authenticating: \(error!)")
                        continuation.resume(throwing: OAuthClientError.errorAuthenticating(error))
                        return
                    }
                    guard let state = state else {
                        logger.error("Error authenticating: no state returned. An unexpected situtation.")
                        continuation.resume(throwing: OAuthClientError.errorAuthenticating(nil))
                        return
                    }
                    logger.info("OAuth flow completed successfully")
                    continuation.resume(returning: state)
                }
            }
        }
    }
}
