//
//  ChatObserver.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import Alamofire
import Foundation
import KeychainAccess
import Starscream
import SwiftUI
import CryptoKit

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
    
    /// The messages stored on the chat.
    @Published var messages: [Message]
    
    /// The participants of the chat.
    @Published var participants: [Participant]
    
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
    
    let salt: Data
    
    /// Create a `ChatObserver` with a an existing `Chat`.
    init(chat: Chat, currentUserId: UUID) {
        self.chatId = chat.id
        self.name = chat.name ?? "Chat"
        self.messages = chat.messages ?? []
        self.participants = chat.participants ?? []
        self.currentUserId = currentUserId
        self.salt = chat.salt
        start(chat: chat)
    }
    
    /// Get a chat from a given chat id.
    func getChat(chatId: UUID) async throws {
        let chat = try await chatActor.get(chatId)
        await set(chat)
    }
    
    func decrypt(_ message: Message) async throws -> String {
        let senderSigningKey = try Curve25519.Signing.PublicKey(rawRepresentation: message.sender.signingKey)
        guard let ourPrivateKey = try await crypto.getPrivateKeyAgreementKey(for: message.chat.id) else {
            throw AffirmateCryptoError.privateKeyNotFound
        }
        let decryptedData = try await crypto.decrypt(message.text, salt: salt, using: ourPrivateKey, from: senderSigningKey)
        guard let text = String(data: decryptedData, encoding: .utf8) else {
            throw AffirmateCryptoError.badUTF8Encoding
        }
        return text
    }
    
    /// Send a new message to the current chat.
    func sendMessage(_ text: String) async throws {
        guard let textData = text.data(using: .utf8) else {
            throw AffirmateCryptoError.failedToGetDataRepresentation
        }
        guard let privateKey = try await crypto.getPrivateSigningKey(for: chatId) else {
            throw AffirmateCryptoError.privateKeyNotFound
        }
        for participant in participants {
            let theirEncryptionKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: participant.encryptionKey)
            let encryptedTextDataUsToThem = try await crypto.encrypt(textData, salt: salt, to: theirEncryptionKey, signedBy: privateKey)
            let newMessageUsToThem = Message.Sealed(
                ephemeralPublicKeyData: encryptedTextDataUsToThem.ephemeralPublicKeyData,
                ciphertext: encryptedTextDataUsToThem.ciphertext,
                signature: encryptedTextDataUsToThem.signature
            )
            let messageCreate = Message.Create(sealed: newMessageUsToThem, recipient: participant.id)
            try write(messageCreate)
        }
    }
    
    /// Add a new participant to the current chat.
    func addParticipants(_ newParticipants: [Participant.Create]) throws {
        
    }
    
    /// Handle new data recieved from the `WebSocket` connection.
    func recieved(_ data: Data) {
        if let newMessage = try? data.decodeWebSocketMessage(Message.self) {
            Task {
                await self.insert(newMessage.data)
                print("Chat: Recieved message:", newMessage)
            }
        } else if let newParticipants = try? data.decodeWebSocketMessage([Participant].self) {
            Task {
                await self.add(newParticipants.data)
                print("Chat: Did add new participant:", newParticipants)
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
    func start(chat: Chat) {
        let sessionToken = chatActor.http.interceptor.sessionToken
        let request = ChatActor.Request.chat(chatId: chat.id, sessionToken: sessionToken)
        guard let urlRequest = try? request.asURLRequest() else {
            assertionFailure()
            return
        }
        start(urlRequest)
        print(request)
    }
    
    /// Insert a new message into the local chat, updating the view.
    @MainActor func insert(_ newMessage: Message) {
        withAnimation {
            self.messages.append(newMessage)
        }
    }
    
    /// Add a new participant to the local chat, updating the view.
    @MainActor func add(_ participants: [Participant]) {
        withAnimation {
            self.participants.append(contentsOf: participants)
        }
    }
    
    /// Set the current chat from another chat instance. Used when the chat is requested from the REST API.
    @MainActor func set(_ chat: Chat) {
        withAnimation {
            self.messages = chat.messages ?? []
            self.participants = chat.participants ?? []
        }
    }
}
