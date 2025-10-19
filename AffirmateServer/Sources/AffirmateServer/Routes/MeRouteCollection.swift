//
//  MeRouteCollection.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import AffirmateShared
import Fluent
import Vapor

struct MeRouteCollection: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // "/me" requires the request header to contain a bearer token
        let me = routes
            .grouped(SessionToken.authenticator(), SessionToken.expirationMiddleware(), SessionToken.guardMiddleware()) // Auth and guard with session token
            .grouped("me")
        
        // MARK: - GET: /me
        me.get() { request async throws -> UserResponse in
            try await request.db.transaction { database in
                let currentUser = try request.auth.require(User.self)
                return try await User.getCurrentUserResponse(currentUser, database: database)
            }
        }
        
        // MARK: - PUT: /me/deviceToken
        me.put("deviceToken") { request async throws -> HTTPStatus in
            let deviceToken = try request.content.decode(APNSDeviceToken.self)
            let currentUser = try request.auth.require(User.self)
            currentUser.apnsId = deviceToken.token
            try await currentUser.update(on: request.db)
            return .ok
        }
        
        // MARK: - DELETE: /me
        me.delete { request async throws -> HTTPStatus in
            let userId: UUID? = request.parameters.get("userId")
            guard let user = try await User.find(userId, on: request.db) else {
                throw Abort(.notFound)
            }
            try await user.delete(on: request.db)
            return .noContent
        }
    }
}
