//
//  ChatObserver.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import AffirmateShared
import Alamofire
import CoreData
import CryptoKit
import Foundation
import KeychainAccess
import Starscream
import SwiftUI

/// An object used on the `View` to display and manage a chat.
class ChatObserver: WebSocketObserver {
    
    /// Whether or not the WebSocket is connected.
    @Published var isConnected = false
    
    /// The key that references the WebSocket connection's `clientId` in the keychain.
    let clientIdKey = Constants.KeyChain.Chat.clientId
    
    /// The `WebSocket` instance.
    var socket: WebSocket?
    
    /// The name of the chat.
    @Published var name: String
    
    /// The url that opens this chat in the app.
    var shareableUrl: URL {
        URL(string: "affirmate://chat?chatId:" + chatId.uuidString)!
    }
    
    /// The actor that manages the requests for managing a chat.
    private let chatActor = ChatActor()
    
    /// The chat's Id.
    var chatId: UUID

    let crypto = AffirmateCrypto()

    let currentUserId: UUID

    let salt: Data?

    var managedObjectContext: NSManagedObjectContext

    private(set) var pendingConfirmations: Set<UUID> = []

    @MainActor func sendDeliveryConfirmation(for messageId: UUID) {
        pendingConfirmations.insert(messageId)
        flushPendingConfirmations()
    }

    @MainActor func flushPendingConfirmations() {
        guard socket != nil, clientId != nil else {
            return
        }
        let confirmations = pendingConfirmations
        for messageId in confirmations {
            do {
                let confirmation = MessageRecievedConfirmation(messageId: messageId)
                try write(confirmation)
                pendingConfirmations.remove(messageId)
            } catch {
                break
            }
        }
    }
    
    /// Create a `ChatObserver` with a an existing `Chat`.
    /// - Parameters:
    ///   - chat: The chat to observe
    ///   - currentUserId: The userId of the currently signed in user
    ///   - managedObjectContext: The context for the user's private icloud core data store.
    init(chat: Chat, currentUserId: UUID, managedObjectContext: NSManagedObjectContext) {
        self.chatId = chat.id!
        self.name = chat.name ?? "Chat"
        self.currentUserId = currentUserId
        self.salt = chat.salt
        self.managedObjectContext = managedObjectContext
        start()
    }
    
    /// Decrypt a message
    /// - Parameter message: The message to decrypt
    /// - Returns: The decrypted message as a `String`.
    func decrypt(_ message: Message) async throws -> String {
        guard let senderSigningKeyData = message.sender?.signingKey else {
            throw DecryptionError.senderSigningKeyDataNotFound
        }
        let senderSigningKey = try Curve25519.Signing.PublicKey(rawRepresentation: senderSigningKeyData)
        guard let salt = salt else {
            throw DecryptionError.saltNotFound
        }
        guard let ourPrivateKey = try await crypto.getPrivateEncryptionKey(for: chatId) else {
            throw DecryptionError.privateKeyNotFound
        }
        guard let ephemeralPublicKeyData = message.ephemeralPublicKeyData, let ciphertext = message.ciphertext, let signature = message.signature else {
            throw DecryptionError.failedToBuildSealedMessage
        }
        let sealedMessage = MessageSealed(
            ephemeralPublicKeyData: ephemeralPublicKeyData,
            ciphertext: ciphertext,
            signature: signature
        )
        let decryptedData = try await crypto.decrypt(sealedMessage, salt: salt, using: ourPrivateKey, from: senderSigningKey)
        guard let text = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.badUTF8Encoding
        }
        return text
    }
    
    /// Send a new message to the current chat.
    func sendMessage(_ text: String, to participants: Array<Participant>) async throws {
        guard let textData = text.data(using: .utf8) else {
            throw EncryptionError.failedToGetDataRepresentation
        }
        guard let salt = salt else {
            throw EncryptionError.saltNotFound
        }
        guard let privateKey = try await crypto.getPrivateSigningKey(for: chatId) else {
            throw EncryptionError.privateKeyNotFound
        }
        for participant in participants {
            guard let participantId = participant.id else {
                throw ChatError.participantIdNotFound
            }
            guard let encryptionKey = participant.encryptionKey else {
                throw EncryptionError.publicKeyNotFound
            }
            let theirEncryptionKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: encryptionKey)
            let encryptedTextDataUsToThem = try await crypto.encrypt(textData, salt: salt, to: theirEncryptionKey, signedBy: privateKey)
            let newMessageUsToThem = MessageSealed(
                ephemeralPublicKeyData: encryptedTextDataUsToThem.ephemeralPublicKeyData,
                ciphertext: encryptedTextDataUsToThem.ciphertext,
                signature: encryptedTextDataUsToThem.signature
            )
            let messageCreate = MessageCreate(sealed: newMessageUsToThem, recipient: participantId)
            try write(messageCreate)
        }
    }
    
    /// Invite new participants to the current chat.
    func inviteParticipants(_ newParticipants: [ParticipantCreate]) throws {
        print(newParticipants)
    }
    
    /// Handle new data recieved from the `WebSocket` connection.
    func recieved(_ data: Data) {
        if let newMessage = try? data.decodeWebSocketMessage(MessageResponse.self) {
            Task {
                do {
                    try await self.insert(newMessage.data)
                } catch {
                    print("Chat: Failed to cache message:", error)
                }
                print("Chat: Recieved message:", newMessage)
            }
        } else {
            print("Chat: Received unrecognized data:", (try? JSONSerialization.jsonObject(with: data) as Any) as? [String: Any] as Any)
        }
    }
    
    /// Don't do anything with text.
    func recieved(_ text: String) { }
}

private extension ChatObserver {
    
    /// Start a new chat.
    func start() {
        Task {
            let sessionToken = await chatActor.getSessionToken()
            let request = ChatActor.Request.chat(chatId: chatId, sessionToken: sessionToken)
            guard let urlRequest = try? request.asURLRequest() else {
                assertionFailure()
                return
            }
            start(urlRequest)
            print(request)
        }
    }
    
    /// Insert a new message into the local chat, updating the view.
    @MainActor func insert(_ messageContent: MessageResponse) throws {
        try withAnimation {
            if try managedObjectContext.doesNotExist(Message.self, id: messageContent.id) {
                let message = Message(context: managedObjectContext)
                message.ciphertext = messageContent.text.ciphertext
                message.createdAt = messageContent.created ?? Date()
                message.updatedAt = messageContent.updated ?? Date()
                message.ephemeralPublicKeyData = messageContent.text.ephemeralPublicKeyData
                message.id = messageContent.id
                message.signature = messageContent.text.signature
                guard let chat = try managedObjectContext.entity(Chat.self, for: messageContent.chat.id) else {
                    throw ChatError.chatIdNotFound
                }
                message.chat = chat

                guard let participants = chat.participants as? Set<Participant> else {
                    throw ChatError.chatWithNoOtherParticipants
                }

                if let sender = participants.first(where: { $0.id == messageContent.sender.id }) {
                    message.sender = sender
                }

                if let recipient = participants.first(where: { $0.id == messageContent.recipient.id}) {
                    message.recipient = recipient
                }

                try managedObjectContext.save()
            }
        }
        sendDeliveryConfirmation(for: messageContent.id)
    }
    
    /// Add a new participant to the local chat, updating the view.
//    @MainActor func add(_ participantsContent: [Participant.GetResponse]) throws {
//        try withAnimation {
//            for participantContent in participantsContent {
//
//                if try managedObjectContext.doesNotExist(Participant.self, id: participantContent.id) {
//
//                    let participant = Participant(context: managedObjectContext)
//                    participant.id = participantContent.id
//                    participant.role = participantContent.role.rawValue
//                    participant.userId = participantContent.user.id
//                    participant.username = participantContent.user.username
//                    participant.signingKey = participantContent.signingKey
//                    participant.encryptionKey = participantContent.encryptionKey
//                    participant.chat = chat
//                }
//            }
//            try managedObjectContext.save()
//        }
//    }
}

extension ChatObserver {
    func flushPendingConfirmationsIfPossible() async {
        await MainActor.run {
            self.flushPendingConfirmations()
        }
    }
}
