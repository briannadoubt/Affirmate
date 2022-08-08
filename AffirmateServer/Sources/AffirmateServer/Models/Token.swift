//
//  UserToken.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor
import JWT

final class Token: Content, Authenticatable {
    static let schema = "token"
    static let expirationTime: TimeInterval = 60 * 15 // 15 minutes
    
    var expiration: ExpirationClaim
    var userId: UUID
    
    init(userId: UUID) {
        self.userId = userId
        self.expiration = ExpirationClaim(value: Date().addingTimeInterval(Self.expirationTime))
    }

    init(user: User) throws {
        self.userId = try user.requireID()
        self.expiration = ExpirationClaim(value: Date().addingTimeInterval(Self.expirationTime))
    }
}

extension Token: JWTPayload {
    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}

extension Token {
    struct Response: Content {
        var token: String
    }
}
