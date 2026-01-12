//
//  SignalProtocol.swift
//  AffirmateShared
//
//  Signal Protocol data types shared between client and server.
//

import Foundation

// MARK: - PreKey Bundle

/// A user's public PreKey bundle for Signal Protocol session establishment.
/// Published to the server and fetched by others to initiate encrypted sessions.
public struct SignalPreKeyBundle: Codable, Equatable {
    /// The user's registration ID
    public var registrationId: UInt32
    /// The user's public identity key
    public var identityKey: Data
    /// The signed PreKey ID
    public var signedPreKeyId: UInt32
    /// The signed PreKey public key
    public var signedPreKey: Data
    /// Signature on the signed PreKey (signed by identity key)
    public var signedPreKeySignature: Data
    /// Optional one-time PreKey ID (consumed after use)
    public var oneTimePreKeyId: UInt32?
    /// Optional one-time PreKey public key
    public var oneTimePreKey: Data?

    public init(
        registrationId: UInt32,
        identityKey: Data,
        signedPreKeyId: UInt32,
        signedPreKey: Data,
        signedPreKeySignature: Data,
        oneTimePreKeyId: UInt32? = nil,
        oneTimePreKey: Data? = nil
    ) {
        self.registrationId = registrationId
        self.identityKey = identityKey
        self.signedPreKeyId = signedPreKeyId
        self.signedPreKey = signedPreKey
        self.signedPreKeySignature = signedPreKeySignature
        self.oneTimePreKeyId = oneTimePreKeyId
        self.oneTimePreKey = oneTimePreKey
    }
}

// MARK: - PreKey Upload

/// Request to upload/update a user's Signal Protocol keys
public struct SignalKeysUpload: Codable {
    /// The user's registration ID
    public var registrationId: UInt32
    /// The user's public identity key
    public var identityKey: Data
    /// The current signed PreKey
    public var signedPreKey: SignedPreKeyUpload
    /// One-time PreKeys to upload
    public var oneTimePreKeys: [OneTimePreKeyUpload]

    public init(
        registrationId: UInt32,
        identityKey: Data,
        signedPreKey: SignedPreKeyUpload,
        oneTimePreKeys: [OneTimePreKeyUpload]
    ) {
        self.registrationId = registrationId
        self.identityKey = identityKey
        self.signedPreKey = signedPreKey
        self.oneTimePreKeys = oneTimePreKeys
    }
}

/// Signed PreKey data for upload
public struct SignedPreKeyUpload: Codable {
    /// The PreKey ID
    public var id: UInt32
    /// The public key data
    public var publicKey: Data
    /// Signature on the public key
    public var signature: Data

    public init(id: UInt32, publicKey: Data, signature: Data) {
        self.id = id
        self.publicKey = publicKey
        self.signature = signature
    }
}

/// One-time PreKey data for upload
public struct OneTimePreKeyUpload: Codable {
    /// The PreKey ID
    public var id: UInt32
    /// The public key data
    public var publicKey: Data

    public init(id: UInt32, publicKey: Data) {
        self.id = id
        self.publicKey = publicKey
    }
}

// MARK: - PreKey Count

/// Response containing the count of remaining one-time PreKeys
public struct PreKeyCountResponse: Codable {
    /// Number of one-time PreKeys remaining on the server
    public var count: Int

    public init(count: Int) {
        self.count = count
    }
}

// MARK: - Signal Message Types

/// Header for Signal Protocol messages
public struct SignalMessageHeader: Codable, Equatable {
    /// Current DH ratchet public key
    public var dhPublicKey: Data
    /// Previous chain message count
    public var previousChainCount: UInt32
    /// Message number in current chain
    public var messageNumber: UInt32

    public init(dhPublicKey: Data, previousChainCount: UInt32, messageNumber: UInt32) {
        self.dhPublicKey = dhPublicKey
        self.previousChainCount = previousChainCount
        self.messageNumber = messageNumber
    }
}

/// A regular Signal Protocol message (after session is established)
public struct SignalEncryptedMessage: Codable, Equatable {
    /// Message header
    public var header: SignalMessageHeader
    /// Encrypted message content
    public var ciphertext: Data
    /// MAC for authentication (contains nonce for ChaChaPoly)
    public var mac: Data

    public init(header: SignalMessageHeader, ciphertext: Data, mac: Data) {
        self.header = header
        self.ciphertext = ciphertext
        self.mac = mac
    }
}

/// Initial message when establishing a new session (PreKey message)
public struct SignalPreKeyMessage: Codable, Equatable {
    /// Sender's registration ID
    public var registrationId: UInt32
    /// Sender's public identity key
    public var identityKey: Data
    /// Sender's ephemeral public key (used in X3DH)
    public var ephemeralKey: Data
    /// ID of the signed PreKey used
    public var signedPreKeyId: UInt32
    /// ID of the one-time PreKey used (if any)
    public var oneTimePreKeyId: UInt32?
    /// The actual encrypted message
    public var message: SignalEncryptedMessage

    public init(
        registrationId: UInt32,
        identityKey: Data,
        ephemeralKey: Data,
        signedPreKeyId: UInt32,
        oneTimePreKeyId: UInt32?,
        message: SignalEncryptedMessage
    ) {
        self.registrationId = registrationId
        self.identityKey = identityKey
        self.ephemeralKey = ephemeralKey
        self.signedPreKeyId = signedPreKeyId
        self.oneTimePreKeyId = oneTimePreKeyId
        self.message = message
    }
}

/// Container for either a PreKey message or regular Signal message
public enum SignalMessageContainer: Codable, Equatable {
    case preKeyMessage(SignalPreKeyMessage)
    case signalMessage(SignalEncryptedMessage)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum MessageType: String, Codable {
        case preKey
        case signal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .preKey:
            let payload = try container.decode(SignalPreKeyMessage.self, forKey: .payload)
            self = .preKeyMessage(payload)
        case .signal:
            let payload = try container.decode(SignalEncryptedMessage.self, forKey: .payload)
            self = .signalMessage(payload)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .preKeyMessage(let message):
            try container.encode(MessageType.preKey, forKey: .type)
            try container.encode(message, forKey: .payload)
        case .signalMessage(let message):
            try container.encode(MessageType.signal, forKey: .type)
            try container.encode(message, forKey: .payload)
        }
    }
}

// MARK: - Signal Message Create

/// Create a new Signal Protocol message
public struct SignalMessageCreate: Codable {
    /// The encrypted message container
    public var message: SignalMessageContainer
    /// The recipient's user ID
    public var recipientId: UUID

    public init(message: SignalMessageContainer, recipientId: UUID) {
        self.message = message
        self.recipientId = recipientId
    }
}

// MARK: - Signal Message Response

/// Response containing a received Signal Protocol message
public struct SignalMessageResponse: Codable {
    /// The message ID
    public var id: UUID
    /// The encrypted message
    public var message: SignalMessageContainer
    /// The sender's user ID
    public var senderId: UUID
    /// The chat ID
    public var chatId: UUID
    /// Timestamp
    public var created: Date?

    public init(
        id: UUID,
        message: SignalMessageContainer,
        senderId: UUID,
        chatId: UUID,
        created: Date? = nil
    ) {
        self.id = id
        self.message = message
        self.senderId = senderId
        self.chatId = chatId
        self.created = created
    }
}
