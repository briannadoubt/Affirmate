//
//  AuthenticationRouteCollection.swift
//  AffirmateServer
//
//  Created by Bri on 7/1/22.
//

import Fluent
import Vapor

struct AuthenticationRouteCollection: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        
        let auth = routes.grouped("auth")
        
        // MARK: - POST: /auth/new
        // "/new" is an open endpoint with no security validation. In the future, work in some middleware to handle denying requests based on the rate of requests, end-user's IP address, variability in account information, and other suspicious activity.
        auth.post("new") { request async throws -> HTTPStatus in
            try await request.db.transaction { database in
                try AffirmateUser.Create.validate(content: request)
                let create = try request.content.decode(AffirmateUser.Create.self)
                guard create.password == create.confirmPassword else {
                    throw Abort(.badRequest, reason: "Passwords do not match")
                }
                let passwordHash = try Bcrypt.hash(create.password)
                let user = AffirmateUser(
                    firstName: create.firstName,
                    lastName: create.lastName,
                    username: create.username,
                    email: create.email,
                    passwordHash: passwordHash
                )
                try await user.create(on: database)
                return .ok
            }
        }
        
        let passwordProtected = auth.grouped(AffirmateUser.authenticator())
        
        // MARK: - GET: /auth/login
        // "/login" requires Basic Authentication data containing the username and password
        passwordProtected.get("login") { request async throws -> AffirmateUser.LoginResponse in
            print(request)
            let user = try request.auth.require(AffirmateUser.self)
            print("User:", user)
            let sessionToken = try user.generateToken()
            print("Session Token:", sessionToken)
            try await sessionToken.save(on: request.db)
            print("Did save token")
            let loginResponse = AffirmateUser.LoginResponse(
                sessionToken: sessionToken,
                user: AffirmateUser.GetResponse(
                    id: try user.requireID(),
                    firstName: user.firstName,
                    lastName: user.lastName,
                    username: user.username,
                    email: user.email
                )
            )
            print("Login Response:", loginResponse)
            return loginResponse
        }
        
        // MARK: - POST: /auth/validate
        // "/validate" checks if there is a valid token on the JWT session.
        // If this check fails the client is expected to re-authenticate with another call to "/login"
        auth.post("validate") { request -> HTTPStatus in
            try request.auth.require(SessionToken.self)
            return .ok
        }
        
        let tokenProtected = auth.grouped(SessionToken.authenticator(), SessionToken.guardMiddleware())
        
        // MARK: - POST: /auth/logout
        tokenProtected.post("logout") { request -> HTTPStatus in
            let token = try request.auth.require(SessionToken.self)
            try await token.delete(on: request.db)
            return .ok
        }
        
        // MARK: - GET: /auth/apple
        // "/apple" verifies the attached JWT Bearer token generated by Apple and sent by the client with Apple's servers for authentication verification.
        // NOTE: This route requires no prior authentication since it is used for sign up.
//        auth.get("apple") { request async throws -> Token.Response in
//            let appleIdentityToken = try await request.jwt.apple.verify()
//            let payload = Token(user: <#T##AffirmateUser#>)
//        }
    }
}
