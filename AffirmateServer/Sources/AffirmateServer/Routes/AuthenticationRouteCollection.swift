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
        // "/signup" is an open endpoint with no security validation. In the future, work in some middleware to handle denying requests based on the rate of requests, end-user's IP address, variability in account information, and other suspicious activity.
        auth.post("new") { request async throws -> User.GetResponse in
            print(request)
            try User.Create.validate(content: request)
            let create = try request.content.decode(User.Create.self)
            guard create.password == create.confirmPassword else {
                throw Abort(.badRequest, reason: "Passwords do not match")
            }
            let passwordHash = try Bcrypt.hash(create.password)
            let user = User(
                firstName: create.firstName,
                lastName: create.lastName,
                username: create.username,
                email: create.email,
                passwordHash: passwordHash
            )
            
            _ = try await user.create(on: request.db)
            let getResponse = user.getResponse
            print(getResponse)
            return getResponse
        }
        // MARK: - GET: /auth
        auth.get { request in
            request.view.render(
                "auth", [
                    "title": "Auth",
                    "header": "Authenticate yourself, human!"
                ]
            )
        }
        // MARK: - POST: /auth/login
        // "/login" requires post data containing the username and password
        let passwordProtected = auth.grouped(User.authenticator()) // Auth with password
        passwordProtected.post("login") { request async throws -> UserToken in
            let user = try request.auth.require(User.self)
            let token = try user.generateToken()
            try await token.save(on: request.db)
            return token
        }
    }
}
