//
//  ChatObserver.swift
//  Affirmate
//
//  Created by Bri on 8/7/22.
//

import Foundation
import SignalProtocol
import SwiftUI

/// An object that manages a list of `Chat` objects updated from the REST API.
final class ChatsObserver: ObservableObject {
    
    static var store = ChatKeyStore()
    
    /// The chats to appear on the view.
    @Published var chats: [Chat] = []
    
    /// The actor that manages the requests for managing a chat.
    let actor = ChatActor()
    
    /// Update the local chats with the chats that were acquired from an API call.
    @MainActor private func updateChats(with newChats: [Chat]) {
        withAnimation {
            self.chats = newChats//.sorted(by: { $0.messages?.last?.created ?? Date() > $1.messages?.last?.created ?? Date() })
        }
    }
    
    /// Initiate a request to fetch and decode all available chats.
    func getChats() async throws {
        let chats = try await actor.get()
        await updateChats(with: chats)
    }
    
    /// Create a new chat.
    func newChat(name: String?, selectedParticipants: [AffirmateUser.Public: Participant.Role]) async throws {
        var (publicKey, preKeys, signedPreKey) = try createChatKeys()
        let participantsCreate = selectedParticipants.map { index in
            let role = index.value
            let publicUser = index.key
            return Participant.Create(
                role: role,
                user: publicUser.id,
                invitedBySignedPreKey: signedPreKey,
                invitedByIdentity: publicKey
            )
        }
        let chatId = UUID()
        try Self.store.signedPreKeyStore.store(signedPreKey: signedPreKey, for: Self.store.signedPreKeyStore.lastId + 1)
        try Self.store.preKeyStore.store(preKey: preKeys[0], for: Self.store.preKeyStore.lastId + 1)
        preKeys.remove(at: 0)
        let createChat = Chat.Create(
            id: chatId,
            name: name,
            participants: participantsCreate,
            publicKey: publicKey,
            preKeys: preKeys,
            signedPreKey: signedPreKey
        )
        try await actor.create(createChat)
    }
    
    func createChatKeys() throws -> (publicKey: Data, preKeys: [Data], signedPreKey: Data) {
        let publicKey = try Self.store.identityKeyStore.getIdentityKeyPublicData()
        let preKeys = try Self.store.createPreKeys(count: 101)
        let signedPreKey = try Self.store.updateSignedPrekey()
        return (publicKey, preKeys, signedPreKey)
    }
}
