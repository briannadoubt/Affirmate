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

        app.tearDown()
    }
}
