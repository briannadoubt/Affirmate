//
//  SignalRouteCollection.swift
//  AffirmateServer
//
//  API routes for Signal Protocol key management.
//

import AffirmateShared
import Fluent
import Vapor

struct SignalRouteCollection: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let signal = routes.grouped("signal")

        // Protected routes require authentication
        let protected = signal.grouped(SessionToken.authenticator(), SessionToken.guardMiddleware())

        // Key management
        protected.post("keys", use: uploadKeys)
        protected.get("keys", ":userId", use: getPreKeyBundle)
        protected.get("keys", "count", use: getPreKeyCount)
        protected.post("keys", "signed", use: updateSignedPreKey)
        protected.post("keys", "onetime", use: uploadOneTimePreKeys)
    }

    // MARK: - Upload Keys

    /// Upload initial Signal Protocol keys for the current user.
    /// POST /signal/keys
    @Sendable
    func uploadKeys(req: Request) async throws -> HTTPStatus {
        let sessionToken = try req.auth.require(SessionToken.self)
        let user = try await sessionToken.$user.get(on: req.db)
        let userId = try user.requireID()

        let upload = try req.content.decode(SignalKeysUpload.self)

        // Check if identity already exists
        if let existing = try await SignalIdentity.query(on: req.db)
            .filter(\.$user.$id == userId)
            .first() {
            // Update existing identity
            existing.registrationId = upload.registrationId
            existing.identityKey = upload.identityKey
            existing.signedPreKeyId = upload.signedPreKey.id
            existing.signedPreKey = upload.signedPreKey.publicKey
            existing.signedPreKeySignature = upload.signedPreKey.signature
            try await existing.save(on: req.db)
        } else {
            // Create new identity
            let identity = SignalIdentity(
                userId: userId,
                registrationId: upload.registrationId,
                identityKey: upload.identityKey,
                signedPreKeyId: upload.signedPreKey.id,
                signedPreKey: upload.signedPreKey.publicKey,
                signedPreKeySignature: upload.signedPreKey.signature
            )
            try await identity.save(on: req.db)
        }

        // Delete existing one-time PreKeys and add new ones
        try await SignalOneTimePreKey.query(on: req.db)
            .filter(\.$user.$id == userId)
            .delete()

        for preKey in upload.oneTimePreKeys {
            let otpk = SignalOneTimePreKey(
                userId: userId,
                preKeyId: preKey.id,
                publicKey: preKey.publicKey
            )
            try await otpk.save(on: req.db)
        }

        return .ok
    }

    // MARK: - Get PreKey Bundle

    /// Get a user's PreKey bundle for session establishment.
    /// GET /signal/keys/:userId
    @Sendable
    func getPreKeyBundle(req: Request) async throws -> SignalPreKeyBundle {
        guard let userIdString = req.parameters.get("userId"),
              let userId = UUID(uuidString: userIdString) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }

        // Get the user's Signal identity
        guard let identity = try await SignalIdentity.query(on: req.db)
            .filter(\.$user.$id == userId)
            .first() else {
            throw Abort(.notFound, reason: "User has not registered Signal keys")
        }

        // Get one available one-time PreKey (and consume it)
        let oneTimePreKey = try await SignalOneTimePreKey.query(on: req.db)
            .filter(\.$user.$id == userId)
            .sort(\.$created, .ascending) // Use oldest first (FIFO)
            .first()

        // Delete the consumed PreKey
        if let otpk = oneTimePreKey {
            try await otpk.delete(on: req.db)
        }

        return SignalPreKeyBundle(
            registrationId: identity.registrationId,
            identityKey: identity.identityKey,
            signedPreKeyId: identity.signedPreKeyId,
            signedPreKey: identity.signedPreKey,
            signedPreKeySignature: identity.signedPreKeySignature,
            oneTimePreKeyId: oneTimePreKey?.preKeyId,
            oneTimePreKey: oneTimePreKey?.publicKey
        )
    }

    // MARK: - Get PreKey Count

    /// Get the count of remaining one-time PreKeys for the current user.
    /// GET /signal/keys/count
    @Sendable
    func getPreKeyCount(req: Request) async throws -> PreKeyCountResponse {
        let sessionToken = try req.auth.require(SessionToken.self)
        let user = try await sessionToken.$user.get(on: req.db)
        let userId = try user.requireID()

        let count = try await SignalOneTimePreKey.query(on: req.db)
            .filter(\.$user.$id == userId)
            .count()

        return PreKeyCountResponse(count: count)
    }

    // MARK: - Update Signed PreKey

    /// Update the signed PreKey (should be done periodically, e.g., weekly).
    /// POST /signal/keys/signed
    @Sendable
    func updateSignedPreKey(req: Request) async throws -> HTTPStatus {
        let sessionToken = try req.auth.require(SessionToken.self)
        let user = try await sessionToken.$user.get(on: req.db)
        let userId = try user.requireID()

        let signedPreKey = try req.content.decode(SignedPreKeyUpload.self)

        guard let identity = try await SignalIdentity.query(on: req.db)
            .filter(\.$user.$id == userId)
            .first() else {
            throw Abort(.notFound, reason: "Signal identity not found")
        }

        identity.signedPreKeyId = signedPreKey.id
        identity.signedPreKey = signedPreKey.publicKey
        identity.signedPreKeySignature = signedPreKey.signature

        try await identity.save(on: req.db)

        return .ok
    }

    // MARK: - Upload One-Time PreKeys

    /// Upload additional one-time PreKeys.
    /// POST /signal/keys/onetime
    @Sendable
    func uploadOneTimePreKeys(req: Request) async throws -> HTTPStatus {
        let sessionToken = try req.auth.require(SessionToken.self)
        let user = try await sessionToken.$user.get(on: req.db)
        let userId = try user.requireID()

        let preKeys = try req.content.decode([OneTimePreKeyUpload].self)

        for preKey in preKeys {
            // Check if this PreKey ID already exists
            let existing = try await SignalOneTimePreKey.query(on: req.db)
                .filter(\.$user.$id == userId)
                .filter(\.$preKeyId == preKey.id)
                .first()

            if existing == nil {
                let otpk = SignalOneTimePreKey(
                    userId: userId,
                    preKeyId: preKey.id,
                    publicKey: preKey.publicKey
                )
                try await otpk.save(on: req.db)
            }
        }

        return .ok
    }
}
