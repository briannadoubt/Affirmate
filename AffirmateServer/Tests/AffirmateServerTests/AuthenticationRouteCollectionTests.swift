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
        let app = Application(.testing)
        defer { app.shutdown() }
        try! app.setUp()
        
        try await app.signUp()
        
        app.tearDown()
    }
    
    // MARK: /auth/login
    func test_login() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try! app.setUp()
        
        try await app
            .signUp()
            .login()
        
        app.tearDown()
    }
    
    // MARK: /auth/logout
    func test_logout() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try! app.setUp()

        try await app
            .signUp()
            .login()
            .logout()

        app.tearDown()
    }

    // MARK: /auth/refresh
    func test_refresh() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try! app.setUp()

        try await app
            .signUp()
            .login()
            .refresh()
      
        let optionalToken = try await SessionToken.query(on: app.db).with(\.$user).first()
        let token = try XCTUnwrap(optionalToken)
        token.expiresAt = Date(timeIntervalSince1970: 0)
        try await token.save(on: app.db)

        try await app.test(.POST, "/auth/logout/") { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: token.value)
        } afterResponse: { response in
            XCTAssertEqual(response.status, .unauthorized)
            let tokens = try await SessionToken.query(on: app.db).all()
            XCTAssertTrue(tokens.isEmpty)
        }

        app.tearDown()
    }

    func test_freshTokenAuthenticatesProtectedRoute() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try! app.setUp()

        try await app
            .signUp()
            .login()

        let optionalToken = try await SessionToken.query(on: app.db).first()
        let token = try XCTUnwrap(optionalToken)
        XCTAssertNotNil(token.expiresAt)
        XCTAssertTrue(token.isValid)

        try await app.test(.POST, "/auth/logout/") { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: token.value)
        } afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        }
        app.tearDown()
    }

    func test_expiredTokenIsRejectedAndPruned() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try! app.setUp()

        try await app
            .signUp()
            .login()

        let optionalToken = try await SessionToken.query(on: app.db).with(\.$user).first()
        let token = try XCTUnwrap(optionalToken)
        token.expiresAt = Date(timeIntervalSince1970: 0)
        try await token.save(on: app.db)

        try await app.test(.POST, "/auth/logout/") { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: token.value)
        } afterResponse: { response in
            XCTAssertEqual(response.status, .unauthorized)
            let tokens = try await SessionToken.query(on: app.db).all()
            XCTAssertTrue(tokens.isEmpty)
        }

        app.tearDown()
    }

    func test_freshTokenAuthenticatesProtectedRoute() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try! app.setUp()

        try await app
            .signUp()
            .login()

        let optionalToken = try await SessionToken.query(on: app.db).first()
        let token = try XCTUnwrap(optionalToken)
        XCTAssertNotNil(token.expiresAt)
        XCTAssertTrue(token.isValid)

        try await app.test(.POST, "/auth/logout/") { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: token.value)
        } afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        }

        app.tearDown()
    }
}
