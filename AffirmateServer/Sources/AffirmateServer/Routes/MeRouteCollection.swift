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
            let authenticatedUser = try request.auth.require(User.self)
            let userID = try authenticatedUser.requireID()

            try await request.db.transaction { database in
                guard let user = try await User.find(userID, on: database) else {
                    throw Abort(.notFound)
                }

                try await SessionToken.query(on: database)
                    .filter(\.$user.$id == userID)
                    .delete()

                try await ChatInvitation.query(on: database)
                    .filter(\.$user.$id == userID)
                    .delete()

                let participants = try await Participant.query(on: database)
                    .filter(\.$user.$id == userID)
                    .all()

                for participant in participants {
                    let participantID = try participant.requireID()

                    try await ChatInvitation.query(on: database)
                        .filter(\.$invitedBy.$id == participantID)
                        .delete()

                    try await Message.query(on: database)
                        .filter(\.$sender.$id == participantID)
                        .delete()

                    try await Message.query(on: database)
                        .filter(\.$recipient.$id == participantID)
                        .delete()

                    try await participant.delete(on: database)
                }

                try await PublicKey.query(on: database)
                    .filter(\.$user.$id == userID)
                    .delete()

                try await user.delete(on: database)
            }

            return .noContent
        }
    }
}
