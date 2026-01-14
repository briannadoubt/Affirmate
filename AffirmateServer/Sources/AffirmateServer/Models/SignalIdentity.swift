//
//  SignalIdentity.swift
//  AffirmateServer
//
//  Signal Protocol identity and key storage for users.
//

import AffirmateShared
import Fluent
import Vapor

/// Stores a user's Signal Protocol identity keys
final class SignalIdentity: Model, Content {

    static let schema = "signal_identity"

    @ID(key: FieldKey.id) var id: UUID?

    /// The user who owns this identity
    @Parent(key: "user_id") var user: User

    /// Registration ID for this user
    @Field(key: "registration_id") var registrationId: UInt32

    /// Public identity key (Curve25519)
    @Field(key: "identity_key") var identityKey: Data
    /// Public identity agreement key (Curve25519)
    @Field(key: "identity_agreement_key") var identityAgreementKey: Data

    /// Current signed PreKey ID
    @Field(key: "signed_prekey_id") var signedPreKeyId: UInt32

    /// Current signed PreKey public key
    @Field(key: "signed_prekey") var signedPreKey: Data

    /// Signature on the signed PreKey
    @Field(key: "signed_prekey_signature") var signedPreKeySignature: Data

    /// Timestamp when signed PreKey was last rotated
    @Timestamp(key: "signed_prekey_timestamp", on: .update, format: .iso8601) var signedPreKeyTimestamp: Date?

    /// Created timestamp
    @Timestamp(key: "created", on: .create, format: .iso8601) var created: Date?

    /// Updated timestamp
    @Timestamp(key: "updated", on: .update, format: .iso8601) var updated: Date?

    init() { }

    init(
        id: UUID? = nil,
        userId: User.IDValue,
        registrationId: UInt32,
        identityKey: Data,
        identityAgreementKey: Data,
        signedPreKeyId: UInt32,
        signedPreKey: Data,
        signedPreKeySignature: Data
    ) {
        self.id = id
        self.$user.id = userId
        self.registrationId = registrationId
        self.identityKey = identityKey
        self.identityAgreementKey = identityAgreementKey
        self.signedPreKeyId = signedPreKeyId
        self.signedPreKey = signedPreKey
        self.signedPreKeySignature = signedPreKeySignature
    }

    struct Migration: AsyncMigration {
        var name: String { "SignalIdentityMigration" }

        func prepare(on database: Database) async throws {
            try await database.schema(SignalIdentity.schema)
                .id()
                .field("user_id", .uuid, .required, .references(User.schema, .id, onDelete: .cascade))
                .field("registration_id", .uint32, .required)
                .field("identity_key", .data, .required)
                .field("identity_agreement_key", .data, .required)
                .field("signed_prekey_id", .uint32, .required)
                .field("signed_prekey", .data, .required)
                .field("signed_prekey_signature", .data, .required)
                .field("signed_prekey_timestamp", .string)
                .field("created", .string)
                .field("updated", .string)
                .unique(on: "user_id")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema(SignalIdentity.schema).delete()
        }
    }
}

/// Stores one-time PreKeys for a user
final class SignalOneTimePreKey: Model, Content {

    static let schema = "signal_one_time_prekey"

    @ID(key: FieldKey.id) var id: UUID?

    /// The user who owns this PreKey
    @Parent(key: "user_id") var user: User

    /// PreKey ID
    @Field(key: "prekey_id") var preKeyId: UInt32

    /// PreKey public key
    @Field(key: "public_key") var publicKey: Data

    /// Created timestamp
    @Timestamp(key: "created", on: .create, format: .iso8601) var created: Date?

    init() { }

    init(
        id: UUID? = nil,
        userId: User.IDValue,
        preKeyId: UInt32,
        publicKey: Data
    ) {
        self.id = id
        self.$user.id = userId
        self.preKeyId = preKeyId
        self.publicKey = publicKey
    }

    struct Migration: AsyncMigration {
        var name: String { "SignalOneTimePreKeyMigration" }

        func prepare(on database: Database) async throws {
            try await database.schema(SignalOneTimePreKey.schema)
                .id()
                .field("user_id", .uuid, .required, .references(User.schema, .id, onDelete: .cascade))
                .field("prekey_id", .uint32, .required)
                .field("public_key", .data, .required)
                .field("created", .string)
                .unique(on: "user_id", "prekey_id")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema(SignalOneTimePreKey.schema).delete()
        }
    }
}
