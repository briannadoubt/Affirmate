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
}


extension Application {
    func setUp() throws {
        try configure(self)
        do { try autoRevert().wait() } catch { print("Failed to auto revert", error) }
        do { try autoMigrate().wait() } catch { print("Failed to auto migrate:", error) }
    }
    
    func tearDown() {
        do { try autoRevert().wait() } catch { print("Failed to auto revert", error) }
    }
    
    @discardableResult
    func signUp(firstName: String = "Meow", lastName: String = "Face", username: String = "meowface", email: String = "meow@fake.com", password: String = "Test123$", confirmPassword: String = "Test123$") async throws -> Application {
        try await test(.POST, "/auth/new/") { request in
            let userCreate = UserCreate(firstName: firstName, lastName: lastName, username: username, email: email, password: password, confirmPassword: password)
            try request.content.encode(userCreate, using: JSONEncoder())
        } afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            
            let optionalUser = try await User.query(on: db).all().first
            let user = try XCTUnwrap(optionalUser)
            XCTAssertEqual(user.firstName, firstName)
            XCTAssertEqual(user.lastName, lastName)
            XCTAssertEqual(user.username, username)
            XCTAssertEqual(user.email, email)
            XCTAssertTrue(try Bcrypt.verify(password, created: user.passwordHash))
        }
        return self
    }
    
    @discardableResult
    func login(firstName: String = "Meow", lastName: String = "Face", username: String = "meowface", email: String = "meow@fake.com", password: String = "Test123$") async throws -> Application {
        try await test(.GET, "/auth/login/") { request in
            request.headers.basicAuthorization = BasicAuthorization(username: username, password: password)
        } afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            
            let optionalSessionToken = try await SessionToken.query(on: db).all().first
            let sessionToken = try XCTUnwrap(optionalSessionToken)
            
            let loginResponse = try response.content.decode(UserLoginResponse.self)
            
            let optionalUser = try await User.query(on: db).with(\.$chatInvitations).all().first
            let user = try XCTUnwrap(optionalUser)
            
            XCTAssertEqual(loginResponse.sessionToken.value, sessionToken.value)
            XCTAssertEqual(loginResponse.user.firstName, user.firstName)
            XCTAssertEqual(loginResponse.user.firstName, firstName)
            XCTAssertEqual(loginResponse.user.lastName, user.lastName)
            XCTAssertEqual(loginResponse.user.lastName, lastName)
            XCTAssertEqual(loginResponse.user.username, user.username)
            XCTAssertEqual(loginResponse.user.username, username)
            XCTAssertEqual(loginResponse.user.email, user.email)
            XCTAssertEqual(loginResponse.user.email, email)
            XCTAssertEqual(loginResponse.user.chatInvitations.isEmpty, user.chatInvitations.isEmpty)
        }
        return self
    }
    
    @discardableResult
    func logout() async throws -> Application {
        try await test(.POST, "/auth/logout/") { request in
            let optionalSessionToken = try await SessionToken.query(on: db).all().first
            let sessionToken = try XCTUnwrap(optionalSessionToken)
            request.headers.bearerAuthorization = BearerAuthorization(token: sessionToken.value)
        } afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            let optionalSessionToken = try await SessionToken.query(on: db).all().first
            XCTAssertNil(optionalSessionToken)
        }
        return self
    }
}
