//
//  ChatObserver.swift
//  Affirmate
//
//  Created by Bri on 8/7/22.
//

import Combine
import CoreData
import Foundation
import SwiftUI

/// An object that manages a list of `Chat` objects updated from the REST API.
final class ChatsObserver: ObservableObject {
    
    /// Format: `[chatId: ChatObserver]
    var chatObservers: [UUID: ChatObserver] = [:]
    
    /// The actor that manages the requests for managing a chat.
    let actor = ChatActor()
    
    /// The actor responsible for generating and signing keys for secure chats.
    let crypto = AffirmateCrypto()
    
    /// The currently signed in user's id
    let currentUserId: UUID
    
    /// The context for managing CoreData
    var managedObjectContext: NSManagedObjectContext
    
    /// Create a new ChatObserver
    /// - Parameters:
    ///   - currentUserId: The currently signed in user's id
    ///   - managedObjectContext: The context for managing CoreData
    init(currentUserId: UUID, managedObjectContext: NSManagedObjectContext) {
        self.currentUserId = currentUserId
        self.managedObjectContext = managedObjectContext
    }
    
    /// Initiate a request to fetch and decode all available chats.
    func getChats() async throws {
        let newChatContent: [Chat.GetResponse] = try await actor.get()
        try updateChatContent(from: newChatContent)
        try deleteStaleChats(from: newChatContent)
    }
    
    /// Update CoreData with the new content from the server.
    /// - Parameter newChatContent: The chat content recieved from the server.
    func updateChatContent(from newChatContent: [Chat.GetResponse]) throws {
        for chatContent in newChatContent {
            let chat = try store(chatContent: chatContent)
            if chatObservers[chatContent.id] == nil {
                chatObservers[chatContent.id] = ChatObserver(chat: chat, currentUserId: currentUserId, managedObjectContext: managedObjectContext)
            }
            for participantContent in chatContent.participants {
                try store(participantContent: participantContent, chat: chat)
            }
            for messageContent in chatContent.messages {
                try store(messageContent: messageContent, chat: chat)
            }
        }
    }
    
    /// Delete chats that are on the device but no longer on the server.
    /// - Parameter newChatContent: The chat content recieved from the server.
    func deleteStaleChats(from newChatContent: [Chat.GetResponse]) throws {
        guard let entityName = Chat.entity().name else {
            throw ChatError.nonexistentEntityName
        }
        let fetchRequest = NSFetchRequest<Chat>(entityName: entityName)
        let chatContentIds = newChatContent.map { $0.id as CVarArg } as NSArray
        fetchRequest.predicate = NSPredicate(format: "NOT (id IN %@)", chatContentIds)
        let fetchedStaleChats = try managedObjectContext.fetch(fetchRequest)
        for staleChat in fetchedStaleChats {
            guard let staleChatId = staleChat.id else {
                managedObjectContext.delete(staleChat)
                continue
            }
            if chatObservers[staleChatId] == nil {
                chatObservers.removeValue(forKey: staleChatId)
            }
            managedObjectContext.delete(staleChat)
        }
        try managedObjectContext.save()
    }
    
    /// Store a chat recieved from the server to CoreData, and update any fields if necessary.
    /// - Parameter chatContent: The chat content recieved from the server.
    /// - Returns: A chat stored on the device with CoreData.`
    func store(chatContent: Chat.GetResponse) throws -> Chat {
        var chat: Chat
        
        if try self.managedObjectContext.doesNotExist(Chat.self, id: chatContent.id) {
            chat = Chat(context: managedObjectContext)
        } else {
            guard let unwrappedChat = try managedObjectContext.entity(Chat.self, for: chatContent.id) else {
                throw ChatError.chatIdNotFound
            }
            chat = unwrappedChat
        }
        
        self.update(&chat, from: chatContent)
        
        try managedObjectContext.save()
        
        return chat
    }
    
    /// Store a participant recieved from the server to CoreData, and update any fields if necessary.
    /// - Parameters:
    ///   - participantContent: The participant content recieved from the server.
    ///   - chat: The chat stored on the device with CoreData.
    func store(participantContent: Participant.GetResponse, chat: Chat) throws {
        var participant: Participant
        
        if try self.managedObjectContext.doesNotExist(Participant.self, id: participantContent.id) {
            participant = Participant(context: managedObjectContext)
        } else {
            guard let unwrappedParticipant = try managedObjectContext.entity(Participant.self, for: participantContent.id) else {
                throw ChatError.participantIdNotFound
            }
            participant = unwrappedParticipant
        }
        
        self.update(&participant, from: participantContent, chat: chat)
        
        try managedObjectContext.save()
    }
    
    /// Store a message recieved from the server to CoreData, and update any fields if necessary.
    /// - Parameters:
    ///   - messageContent: The message content recieved from the server.
    ///   - chat: The chat stored on the device with CoreData.
    func store(messageContent: Message.GetResponse, chat: Chat) throws {
        var message: Message
        
        if try managedObjectContext.doesNotExist(Message.self, id: messageContent.id) {
            message = Message(context: managedObjectContext)
        } else {
            guard let unwrappedMessage = try managedObjectContext.entity(Message.self, for: messageContent.id) else {
                throw ChatError.messageIdNotFound
            }
            message = unwrappedMessage
        }
        
        update(message: &message, from: messageContent, chat: chat)
        
        if let participants = chat.participants as? Set<Participant> {
            if let sender = participants.first(where: { $0.id == messageContent.sender.id }) {
                message.sender = sender
            }
            if let recipient = participants.first(where: { $0.id == messageContent.recipient.id}) {
                message.recipient = recipient
            }
        }
        
        try managedObjectContext.save()
    }
    
    /// Update a participant with the content from the server
    /// - Parameters:
    ///   - participant: The participant to update.
    ///   - participantContent: The participant content recieved from the server.
    ///   - chat: The chat stored on the device with CoreData.
    func update(_ participant: inout Participant, from participantContent: Participant.GetResponse, chat: Chat) {
        participant.id = participantContent.id
        participant.role = participantContent.role.rawValue
        participant.userId = participantContent.user.id
        participant.username = participantContent.user.username
        participant.signingKey = participantContent.signingKey
        participant.encryptionKey = participantContent.encryptionKey
        participant.chat = chat
    }
    
    /// Update a chat with the content from the server
    /// - Parameters:
    ///   - chat: The chat to update.
    ///   - chatContent: The chat content recieved from the server.
    func update(_ chat: inout Chat, from chatContent: Chat.GetResponse) {
        chat.id = chatContent.id
        chat.name = chatContent.name
        chat.salt = chatContent.salt
    }
    
    /// Update a message with the content from the server
    /// - Parameters:
    ///   - message: The message to update.
    ///   - messageContent: The message content recieved from the server.
    ///   - chat: The chat stored on the device with CoreData.
    func update(message: inout Message, from messageContent: Message.GetResponse, chat: Chat) {
        message.ciphertext = messageContent.text.ciphertext
        message.createdAt = messageContent.created ?? Date()
        message.updatedAt = messageContent.updated ?? Date()
        message.ephemeralPublicKeyData = messageContent.text.ephemeralPublicKeyData
        message.id = messageContent.id
        message.signature = messageContent.text.signature
        message.chat = chat
    }
    
    /// Create a new chat.
    /// - Parameters:
    ///   - name: The name of the chat
    ///   - selectedParticipants: The participants who will be invited.
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
