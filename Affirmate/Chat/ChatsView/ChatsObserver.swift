//
//  ChatObserver.swift
//  Affirmate
//
//  Created by Bri on 8/7/22.
//

import Foundation
import SwiftUI

/// An object that manages a list of `Chat` objects updated from the REST API.
final class ChatsObserver: ObservableObject {
    
    /// The chats to appear on the view.
//    @Published var chats: [Chat.GetResponse] = []
    
    /// Format: `[chatId: ChatObserver]
    var chatObservers: [UUID: ChatObserver] = [:]
    
    /// The actor that manages the requests for managing a chat.
    let actor = ChatActor()
    
    /// The actor responsible for generating and signing keys for secure chats.
    let crypto = AffirmateCrypto()
    
    let currentUserId: UUID
    
    init(currentUserId: UUID) {
        self.currentUserId = currentUserId
    }
    
    /// Update the local chats with the chats that were acquired from an API call.
    @MainActor private func updateChats(with newChats: [Chat.GetResponse]) {
        withAnimation {
//            let difference = newChats.difference(from: chats) { element, chat in
//                if let elementMessages = element.messages, let chatMessages = chat.messages {
//                    return elementMessages.elementsEqual(chatMessages)
//                }
//                return false
//            }
//            for change in difference.inferringMoves() {
//                switch change {
//                case .insert(let offset, let newChat, _):
//                    chats.insert(newChat, at: offset)
//                    if chatObservers[newChat.id] == nil {
//                        chatObservers[newChat.id] = ChatObserver(chat: newChat, currentUserId: currentUserId)
//                    }
//                case .remove(let offset, let chat, _):
//                    chats.remove(at: offset)
//                    if
//                        chatObservers[chat.id] != nil,
//                        newChats.contains(chat)
//                    {
//                        chatObservers.removeValue(forKey: chat.id)
//                    }
//                }
//            }
        }
    }
    
    /// Initiate a request to fetch and decode all available chats.
    func getChats() async throws {
        let chats = try await actor.get()
        await updateChats(with: chats)
    }
    
    /// Create a new chat.
    func newChat(name: String?, selectedParticipants: [AffirmateUser.Public: Participant.Role]) async throws {
        let participantsCreate = selectedParticipants.map { index in
            let role = index.value
            let publicUser = index.key
            return Participant.Create(
                role: role,
                user: publicUser.id
            )
        }
        let chatId = UUID()
        let (signingPublicKey, _) = try await crypto.generateSigningKeyPair(for: chatId)
        let (encryptionPublicKey, _) = try await crypto.generateEncryptionKeyPair(for: chatId)
        let salt = try await crypto.generateSalt()
        let createChat = Chat.Create(
            id: chatId,
            name: name,
            salt: salt,
            participants: participantsCreate,
            signingKey: signingPublicKey,
            encryptionKey: encryptionPublicKey
        )
        print(createChat)
        try await actor.create(createChat)
    }
}
