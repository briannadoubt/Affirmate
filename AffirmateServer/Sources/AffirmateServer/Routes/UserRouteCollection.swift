//
//  UserRouteCollection.swift
//  AffirmateServer
//
//  Created by Bri on 8/27/22.
//

import Fluent
import Vapor

struct UserRouteCollection: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        
        let tokenProtected = routes.grouped(SessionToken.authenticator(), SessionToken.guardMiddleware())
        let users = tokenProtected.grouped("users")
        
        users.get("find") { request async throws -> [AffirmateUser.Public] in
            let usernameSearchString = try request.query.get(String.self, at: "username")
            return try await AffirmateUser
                .query(on: request.db)
                .filter(\.$username =~ usernameSearchString.lowercased())
                .all()
                .map { try $0.publicResponse() }
        }
        
        users.get(":userId") { request async throws -> AffirmateUser.Public in
            guard
                let userIdString = request.parameters.get("userId"),
                let userId = UUID(uuidString: userIdString),
                let user = try await AffirmateUser.find(userId, on: request.db)
            else {
                throw Abort(.notFound)
            }
            return AffirmateUser.Public(id: userId, username: user.username)
        }
    }
}
