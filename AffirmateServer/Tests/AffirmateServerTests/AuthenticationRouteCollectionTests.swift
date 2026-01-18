//
//  AuthenticationRouteCollectionTests.swift
//  
//
//  Created by Bri on 8/2/22.
//

@testable import AffirmateServer
import AffirmateShared
import Vapor
import XCTest
import XCTVapor

final class AuthenticationRouteCollectionTests: XCTestCase {
    // MARK: /auth/new
    func test_newUser() async throws {
        let app = try await Application.makeConfiguredTestApplication(.testing)
        defer { Task { await app.shutdownTestApplication() } }

        try await app.signUp()
    }

    // MARK: /auth/login
    func test_login() async throws {
        let app = try await Application.makeConfiguredTestApplication(.testing)
        defer { Task { await app.shutdownTestApplication() } }

        try await app.signUp()
        try await app.login()
    }

    // MARK: /auth/logout
    func test_logout() async throws {
        let app = try await Application.makeConfiguredTestApplication(.testing)
        defer { Task { await app.shutdownTestApplication() } }

        try await app.signUp()
        try await app.login()
        try await app.logout()
    }

    // MARK: /auth/refresh
    func test_refresh() async throws {
        let app = try await Application.makeConfiguredTestApplication(.testing)
        defer { Task { await app.shutdownTestApplication() } }

        try await app.signUp()
        try await app.login()

        let optionalToken = try await SessionToken.query(on: app.db).with(\.$user).first()
        let token = try XCTUnwrap(optionalToken)
        token.expiresAt = Date(timeIntervalSince1970: 0)
        try await token.save(on: app.db)

        try await app.testable().test(.POST, "/auth/logout/") { request async throws in
            request.headers.bearerAuthorization = BearerAuthorization(token: token.value)
        } afterResponse: { response async throws in
            XCTAssertEqual(response.status, .unauthorized)
            let tokens = try await SessionToken.query(on: app.db).all()
            XCTAssertTrue(tokens.isEmpty)
        }
    }

    func test_freshTokenAuthenticatesProtectedRoute() async throws {
        let app = try await Application.makeConfiguredTestApplication(.testing)
        defer { Task { await app.shutdownTestApplication() } }

        try await app.signUp()
        try await app.login()

        let optionalToken = try await SessionToken.query(on: app.db).first()
        let token = try XCTUnwrap(optionalToken)
        XCTAssertNotNil(token.expiresAt)
        XCTAssertTrue(token.isValid)

        try await app.testable().test(.POST, "/auth/logout/") { request async throws in
            request.headers.bearerAuthorization = BearerAuthorization(token: token.value)
        } afterResponse: { response async throws in
            XCTAssertEqual(response.status, .ok)
        }
    }

    func test_expiredTokenIsRejectedAndPruned() async throws {
        let app = try await Application.makeConfiguredTestApplication(.testing)
        defer { Task { await app.shutdownTestApplication() } }

        try await app.signUp()
        try await app.login()

        let optionalToken = try await SessionToken.query(on: app.db).with(\.$user).first()
        let token = try XCTUnwrap(optionalToken)
        token.expiresAt = Date(timeIntervalSince1970: 0)
        try await token.save(on: app.db)

        try await app.testable().test(.POST, "/auth/logout/") { request async throws in
            request.headers.bearerAuthorization = BearerAuthorization(token: token.value)
        } afterResponse: { response async throws in
            XCTAssertEqual(response.status, .unauthorized)
            let tokens = try await SessionToken.query(on: app.db).all()
            XCTAssertTrue(tokens.isEmpty)
        }
    }
}
