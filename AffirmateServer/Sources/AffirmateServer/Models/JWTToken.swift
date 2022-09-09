//
//  UserToken.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor
import JWT

final class JWTToken: Content, Authenticatable {
    static let schema = "jwt_token"
    static let expirationTime = Date.distantFuture.timeIntervalSinceNow
    
    var expiration: ExpirationClaim
    var userId: UUID
    
    init(userId: UUID) {
        self.userId = userId
        self.expiration = ExpirationClaim(value: Date().addingTimeInterval(Self.expirationTime))
    }

    init(user: AffirmateUser) throws {
        self.userId = try user.requireID()
        self.expiration = ExpirationClaim(value: Date().addingTimeInterval(Self.expirationTime))
    }
}

extension JWTToken: JWTPayload {
    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}

extension JWTToken {
    struct Response: Content {
        var jwtToken: String
        var sesionToken: SessionToken
    }
}
