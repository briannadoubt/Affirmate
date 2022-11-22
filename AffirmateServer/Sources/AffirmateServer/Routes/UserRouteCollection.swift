//
//  UserRouteCollection.swift
//  AffirmateServer
//
//  Created by Bri on 8/27/22.
//

import AffirmateShared
import Fluent
import Vapor

struct UserRouteCollection: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        
        let tokenProtected = routes.grouped(SessionToken.authenticator(), SessionToken.guardMiddleware())
        let users = tokenProtected.grouped("users")
        
        users.get("find") { request async throws -> [UserPublic] in
            let usernameSearchString = try request.query.get(String.self, at: "username")
            return try await User
                .query(on: request.db)
                .filter(\.$username =~ usernameSearchString.lowercased())
                .all()
                .map { try $0.publicResponse() }
        }
        
        users.get(":userId") { request async throws -> UserPublic in
            guard
                let userIdString = request.parameters.get("userId"),
                let userId = UUID(uuidString: userIdString),
                let user = try await User.find(userId, on: request.db)
            else {
                throw Abort(.notFound)
            }
            return UserPublic(id: userId, username: user.username)
        }
    }
}
