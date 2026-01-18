//
//  Application+Testable.swift
//  AffirmateServerTests
//
//  Created by Bri on 8/6/22.
//

import AffirmateShared
@testable import AffirmateServer
import XCTVapor

extension Application {
    static func makeTestApplication(_ environment: Environment = .testing) async throws -> Application {
        try await Application.make(environment)
    }

    static func makeConfiguredTestApplication(_ environment: Environment = .testing) async throws -> Application {
        let app = try await makeTestApplication(environment)
        try await app.setUp()
        return app
    }

    func setUp() async throws {
        try await configure(self)
        do { try await autoRevert().get() } catch { print("Failed to auto revert", error) }
        do { try await autoMigrate().get() } catch { print("Failed to auto migrate:", error) }
    }

    func tearDown() async {
        do { try await autoRevert().get() } catch { print("Failed to auto revert", error) }
    }

    func shutdownTestApplication() async {
        await tearDown()
        do {
            try await asyncShutdown()
        } catch {
            print("Failed to async shutdown application:", error)
        }
    }

    @discardableResult
    func signUp(firstName: String = "Meow", lastName: String = "Face", username: String = "meowface", email: String = "meow@fake.com", password: String = "Test123$", confirmPassword: String = "Test123$") async throws -> Application {
        try await self.testable().test(.POST, "/auth/new/") { request async throws in
            let userCreate = UserCreate(firstName: firstName, lastName: lastName, username: username, email: email, password: password, confirmPassword: password)
            try request.content.encode(userCreate, using: JSONEncoder())
        } afterResponse: { response async throws in
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
        try await self.testable().test(.GET, "/auth/login/") { request async throws in
            request.headers.basicAuthorization = BasicAuthorization(username: username, password: password)
        } afterResponse: { response async throws in
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
        try await self.testable().test(.POST, "/auth/logout/") { request async throws in
            let optionalSessionToken = try await SessionToken.query(on: db).all().first
            let sessionToken = try XCTUnwrap(optionalSessionToken)
            request.headers.bearerAuthorization = BearerAuthorization(token: sessionToken.value)
        } afterResponse: { response async throws in
            XCTAssertEqual(response.status, .ok)
            let optionalSessionToken = try await SessionToken.query(on: db).all().first
            XCTAssertNil(optionalSessionToken)
        }
        return self
    }

    @discardableResult
    func refresh() async throws -> Application {
        var previousTokenID: UUID?
        var previousTokenValue: String?

        try await self.testable().test(.POST, "/auth/refresh/") { request async throws in
            let optionalSessionToken = try await SessionToken.query(on: db).all().first
            let sessionToken = try XCTUnwrap(optionalSessionToken)

            previousTokenID = try sessionToken.requireID()
            previousTokenValue = sessionToken.value

            request.headers.bearerAuthorization = BearerAuthorization(token: sessionToken.value)
        } afterResponse: { response async throws in
            XCTAssertEqual(response.status, .ok)

            let refreshResponse = try response.content.decode(SessionTokenResponse.self)

            let tokens = try await SessionToken.query(on: db).all()
            XCTAssertEqual(tokens.count, 1)
            let storedToken = try XCTUnwrap(tokens.first)

            XCTAssertEqual(try storedToken.requireID(), refreshResponse.id)
            XCTAssertEqual(storedToken.value, refreshResponse.value)

            if let previousTokenID {
                XCTAssertNotEqual(try storedToken.requireID(), previousTokenID)
            }

            if let previousTokenValue {
                XCTAssertNotEqual(storedToken.value, previousTokenValue)

                try await self.testable().test(.POST, "/auth/logout/") { request async throws in
                    request.headers.bearerAuthorization = BearerAuthorization(token: previousTokenValue)
                } afterResponse: { response async throws in
                    XCTAssertEqual(response.status, .unauthorized)
                }
            }
        }

        return self
    }
}
