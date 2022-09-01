//
//  MeRouteCollection.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor

struct APNSDeviceToken: Content {
    var token: Data?
}

struct MeRouteCollection: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // "/me" requires the request header to contain a bearer token
        let me = routes
            .grouped(SessionToken.authenticator(), SessionToken.guardMiddleware()) // Auth and guard with session token
            .grouped("me")
        
        // MARK: - GET: /me
        me.get() { request async throws -> AffirmateUser.GetResponse in
            try request.auth.require(AffirmateUser.self).getResponse
        }
        
        // MARK: - PUT: /me/deviceToken
        me.put("deviceToken") { request async throws -> HTTPStatus in
            let deviceToken = try request.content.decode(APNSDeviceToken.self)
            let currentUser = try request.auth.require(AffirmateUser.self)
            currentUser.apnsId = deviceToken.token
            try await currentUser.update(on: request.db)
            return .ok
        }
        
        // MARK: - DELETE: /me
        me.delete { request async throws -> HTTPStatus in
            let userId: UUID? = request.parameters.get("userId")
            guard let user = try await AffirmateUser.find(userId, on: request.db) else {
                throw Abort(.notFound)
            }
            try await user.delete(on: request.db)
            return .noContent
        }
    }
}
