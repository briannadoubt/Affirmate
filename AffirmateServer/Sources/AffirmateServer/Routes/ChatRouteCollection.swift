//
//  ChatRouteCollection.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import AffirmateShared
import Fluent
import Vapor

struct ChatRouteCollection: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let tokenProtected = routes.grouped(SessionToken.authenticator(), SessionToken.expirationMiddleware(), SessionToken.guardMiddleware()) // Auth and guard with session token
        let chats = tokenProtected.grouped("chats")
        
        // MARK: - POST "/chats": Creates a new blank chat, adds the current user as a participant, and invites any other specified users to the chat.
        chats.post { request async throws -> HTTPStatus in
            try await request.db.transaction { database in
                let chatCreate = try request.content.decode(ChatCreate.self)
                let newChat = Chat(
                    id: chatCreate.id,
                    name: chatCreate.name,
                    salt: chatCreate.salt
                )
                try await newChat.save(on: database)
                let currentUser = try request.auth.require(User.self)
                let newPublicKey = try PublicKey(
                    signingKey: chatCreate.signingKey,
                    encryptionKey: chatCreate.encryptionKey,
                    user: try currentUser.requireID(),
                    chat: newChat.requireID()
                )
                try await newPublicKey.save(on: database)
                let newParticipant = Participant(
                    role: .admin,
                    user: try currentUser.requireID(),
                    chat: try newChat.requireID(),
                    publicKey: try newPublicKey.requireID()
                )
                try await newChat.$participants.create(newParticipant, on: database)
                for participantCreate in chatCreate.participants {
                    let invitation = ChatInvitation(
                        role: participantCreate.role,
                        user: participantCreate.user,
                        invitedBy: try newParticipant.requireID(),
                        chat: try newChat.requireID()
                    )
                    try await invitation.save(on: database)
                }
            }
            return .ok
        }
        
        // MARK: - GET "/chats": Returns all authorized chats based on the user token session.
        chats.get { request async throws -> [ChatResponse] in
            try await request.db.transaction { database in
                let currentUser = try request.auth.require(User.self)
                let chats = try await getChats(from: database, currentUser: currentUser)
                let response = try chatResponses(from: chats, currentUser: currentUser)

                let currentUserId = try currentUser.requireID()
                let recipientIds = try chats
                    .compactMap { chat in
                        try chat.participants.first(where: { participant in
                            try participant.user.requireID() == currentUserId
                        })?.requireID()
                    }

                if !recipientIds.isEmpty {
                    try await Message.query(on: database)
                        .filter(\.$recipient.$id ~~ recipientIds)
                        .delete()
                }

                return response
            }
        }
        
        let specificChat = chats.grouped(":chatId")
        
        // MARK: - POST "/chat/:chatId/invite": Invite a new user to the chat.
        let invite = specificChat.grouped("invite")
        invite.post { request async throws -> HTTPStatus in
            try await request.db.transaction { database in
                let currentUser = try request.auth.require(User.self)
                let invitationCreate = try request.content.decode(ChatInvitationCreate.self)
                let (chatId, _) = try await getChat(request: request, database: database)

                // Find the current user's participant record for this chat
                guard let invitingParticipant = try await Participant.query(on: database)
                    .filter(\.$user.$id == currentUser.requireID())
                    .filter(\.$chat.$id == chatId)
                    .first()
                else {
                    throw Abort(.forbidden, reason: "You are not a participant of this chat")
                }

                // Only admins can invite new participants
                guard invitingParticipant.role == .admin else {
                    throw Abort(.forbidden, reason: "Only admins can invite new participants")
                }

                let invitation = ChatInvitation(
                    role: invitationCreate.role,
                    user: invitationCreate.user,
                    invitedBy: try invitingParticipant.requireID(),
                    chat: chatId
                )
                try await invitation.save(on: database)
                return .ok
            }
        }
        
        // MARK: - POST "/chat/:chatId/join": Join a chat via an invitation.
        let join = specificChat.grouped("join")
        join.post { request async throws -> HTTPStatus in
            try await request.db.transaction{ database in
                let confirmation = try request.content.decode(ChatInvitationJoin.self)
                let currentUser = try request.auth.require(User.self)
                let (chatId, chat) = try await getChat(request: request, database: database)
                let invitation = try await getInvitation(chat: chat, currentUser: currentUser, database: database)
                try await invitation.$user.load(on: database)
                
                let newPublicKey = PublicKey(
                    signingKey: confirmation.signingKey,
                    encryptionKey: confirmation.encryptionKey,
                    user: try currentUser.requireID(),
                    chat: chatId
                )
                try await newPublicKey.save(on: database)
                let newParticipant = Participant(
                    role: invitation.role,
                    user: try currentUser.requireID(),
                    chat: chatId,
                    publicKey: try newPublicKey.requireID()
                )
                try await chat.$participants.create(newParticipant, on: database)
                
                try await deleteInvitation(id: confirmation.id, currentUser: currentUser, chat: chat, database: database)
                return .ok
            }
        }
        
        // MARK: - POST "/chat/:chatId/decline": Join a chat via an invitation.
        let decline = specificChat.grouped("decline")
        decline.post { request async throws -> HTTPStatus in
            try await request.db.transaction{ database in
                let declination = try request.content.decode(ChatInvitationDecline.self)
                let currentUser = try request.auth.require(User.self)
                guard
                    let chatIdString = request.parameters.get("chatId"),
                    let chatId = UUID(uuidString: chatIdString),
                    let chat = try await Chat.find(chatId, on: database)
                else {
                    throw Abort(.badRequest)
                }
                try await deleteInvitation(id: declination.id, currentUser: currentUser, chat: chat, database: database)
                return .ok
            }
        }
    }
}

extension ChatRouteCollection {
    
    func getChats(from database: Database, currentUser: User) async throws -> [Chat] {
        try await currentUser.$chats.query(on: database)
            .with(\Chat.$messages) {
                $0.with(\Message.$sender) {
                    $0.with(\Participant.$user)
                        .with(\Participant.$publicKey)
                }
                .with(\Message.$recipient) {
                    $0.with(\Participant.$user)
                        .with(\Participant.$publicKey)
                }
            }
            .with(\Chat.$participants) {
                $0.with(\Participant.$user)
                    .with(\Participant.$publicKey)
            }
            .all()
    }
    
    func getChat(request: Request, database: Database) async throws -> (UUID, Chat) {
        guard
            let chatIdString = request.parameters.get("chatId"),
            let chatId = UUID(uuidString: chatIdString),
            let chat = try await Chat.find(chatId, on: database)
        else {
            throw Abort(.badRequest)
        }
        return (chatId, chat)
    }
    
    func chatResponses(from chats: [Chat], currentUser: User) throws -> [ChatResponse] {
        try chats.compactMap { chat in
            return ChatResponse(
                id: try chat.requireID(),
                name: chat.name,
                messages: try messageResponses(from: chat, currentUser: currentUser),
                participants: try participantResponses(from: chat),
                salt: chat.salt
            )
        }
    }
    
    func participantResponses(from chat: Chat) throws -> [ParticipantResponse] {
        try chat.participants.map { participant in
            ParticipantResponse(
                id: try participant.requireID(),
                role: participant.role,
                user: UserParticipantResponse(
                    id: try participant.user.requireID(),
                    username: participant.user.username
                ),
                chat: ChatParticipantResponse(id: try chat.requireID()),
                signingKey: participant.publicKey.signingKey,
                encryptionKey: participant.publicKey.encryptionKey
            )
        }
    }
    
    func messageResponses(from chat: Chat, currentUser: User) throws -> [MessageResponse] {
        try chat.messages.filter({ $0.recipient.user.id == currentUser.id }).map { message in
            MessageResponse(
                id: try message.requireID(),
                text: MessageSealed(
                    ephemeralPublicKeyData: message.ephemeralPublicKeyData,
                    ciphertext: message.ciphertext,
                    signature: message.signature
                ),
                chat: ChatMessageResponse(id: try chat.requireID()),
                sender: try sender(from: message, chat: chat),
                recipient: try recipient(from: message, chat: chat),
                created: message.created
            )
        }
    }
    
    func sender(from message: Message, chat: Chat) throws -> ParticipantResponse {
        ParticipantResponse(
            id: try message.sender.requireID(),
            role: message.sender.role,
            user: UserParticipantResponse(
                id: try message.sender.user.requireID(),
                username: message.sender.user.username
            ),
            chat: ChatParticipantResponse(id: try chat.requireID()),
            signingKey: message.sender.publicKey.signingKey,
            encryptionKey: message.sender.publicKey.encryptionKey
        )
    }
    
    func recipient(from message: Message, chat: Chat) throws -> ParticipantResponse {
        ParticipantResponse(
            id: try message.recipient.requireID(),
            role: message.recipient.role,
            user: UserParticipantResponse(
                id: try message.recipient.user.requireID(),
                username: message.recipient.user.username
            ),
            chat: ChatParticipantResponse(id: try chat.requireID()),
            signingKey: message.recipient.publicKey.signingKey,
            encryptionKey: message.recipient.publicKey.encryptionKey
        )
    }
    
    func getInvitation(chat: Chat, currentUser: User, database: Database) async throws -> ChatInvitation {
        guard let invitation = try await chat.$openInvitations
            .query(on: database)
            .filter(\.$user.$id == currentUser.requireID())
            .filter(\.$chat.$id == chat.requireID())
            .all()
            .first
        else {
            throw Abort(.forbidden)
        }
        return invitation
    }
    
//    func invite(_ participantCreate: Participant.Create, from invitedBy: UUID, to chat: Chat, on database: Database) async throws {
//        try await invite(participantCreate.user, to: chat.requireID(), from: invitedBy, as: participantCreate.role, on: database)
//    }
//
//    func invite(_ user: UUID, to chat: UUID, from invitedBy: UUID, as role: Participant.Role, on database: Database) async throws {
//        let chatInvitation = ChatInvitation(role: role, user: user, invitedBy: invitedBy, chat: chat)
//        try await chatInvitation.save(on: database)
//    }
    
    func deleteInvitation(id: UUID, currentUser: User, chat: Chat, database: Database) async throws {
        try await currentUser.$chatInvitations.detach(chat, on: database)
        if let chatInvitation = try await ChatInvitation.find(id, on: database) {
            try await chatInvitation.delete(on: database)
        }
    }
}
