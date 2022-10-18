//
//  ChatObserver.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import Alamofire
import Foundation
import KeychainAccess
import SignalProtocol
import Starscream
import SwiftUI

/// An object used on the `View` to display and manage a chat.
class ChatObserver: WebSocketObserver {
    
    var session: SessionCipher<ChatKeyStore>
    
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
    
    /// Create a `ChatObserver` with a an existing `Chat`.
    init(chat: Chat, currentUserId: UUID) {
        self.chatId = chat.id
        self.name = chat.name ?? "Chat"
        self.messages = chat.messages ?? []
        self.participants = chat.participants ?? []
        self.session = SessionCipher(store: ChatsObserver.store, remoteAddress: AffirmateAddress(identifier: chat.id, deviceId: 0))
        setUpSession(currentUserId: currentUserId)
        start(chat: chat)
    }
    
    func setUpSession(currentUserId: UUID) {
        if
            let currentParticipant = self.participants.first(where: { $0.user.id == currentUserId }),
            let preKey = AffirmateKeychain.chat[data: "preKey." + chatId.uuidString]
        {
            processPreKeyBundle(preKey: preKey, signedPreKey: currentParticipant.signedPreKey)
            if AffirmateKeychain.chat[data: "signedPreKey." + chatId.uuidString] == nil {
                AffirmateKeychain.chat[data: "signedPreKey." + chatId.uuidString] = currentParticipant.signedPreKey
            }
        }
    }
    
    func processPreKeyBundle(preKey: Data, signedPreKey: Data) {
        do {
            let preKeyBundle = try SessionPreKeyBundle(
                preKey: preKey,
                signedPreKey: signedPreKey,
                identityKey: ChatsObserver.store.identityKeyStore.getIdentityKeyPublicData()
            )
            try session.process(preKeyBundle: preKeyBundle)
        } catch {
            print("Failed to precess preKey bundle:", error)
        }
    }
    
    func encrypt(_ text: String) throws -> Data {
        guard let messageData = text.data(using: .utf8) else {
            throw ChatError.failedToConvertMessageContentIntoData
        }
        return try session.encrypt(messageData).data
    }
    
    func decrypt(_ encryptedMessageData: Data?) -> String {
        if
            let encryptedMessageData = encryptedMessageData,
            let decryptedMessageData = try? session.decrypt(CipherTextMessage(from: encryptedMessageData)),
            let message = String(data: decryptedMessageData, encoding: .utf8)
        {
            return message
        } else {
            return "Failed to decrypt"
        }
    }
    
    /// Get a chat from a given chat id.
    func getChat(chatId: UUID) async throws {
        let chat = try await chatActor.get(chatId)
        await set(chat)
    }
    
    /// Send a new message to the current chat.
    func sendMessage(_ text: String) throws {
        let encryptedText = try encrypt(text)
        let newMessage = Message.Create(text: encryptedText)
        try write(newMessage)
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
