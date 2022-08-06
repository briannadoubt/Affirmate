//
//  MeRouteCollection.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor

struct MeRouteCollection: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // "/me" requires the request header to contain a bearer token
        let me = routes
            .grouped("me")
            .grouped(UserToken.authenticator()) // Auth with token
        // MARK: - GET: /me
        me.get() { request async throws -> User in
            try request.auth.require(User.self)
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
