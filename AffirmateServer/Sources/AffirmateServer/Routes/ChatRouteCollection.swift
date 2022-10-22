//
//  ChatRouteCollection.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor

struct ChatRouteCollection: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let tokenProtected = routes.grouped(SessionToken.authenticator(), SessionToken.guardMiddleware()) // Auth and guard with session token
        let chats = tokenProtected.grouped("chats")
        
        // MARK: - POST "/chats": Creates a new blank chat, adds the current user as a participant, and invites any other specified users to the chat.
        chats.post { request async throws -> HTTPStatus in
            try await request.db.transaction { database in
                let chatCreate = try request.content.decode(Chat.Create.self)
                let newChat = Chat(
                    id: chatCreate.id,
                    name: chatCreate.name,
                    salt: chatCreate.salt
                )
                try await newChat.save(on: database)
                let currentUser = try request.auth.require(AffirmateUser.self)
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
        chats.get { request async throws -> [Chat.GetResponse] in
            try await request.db.transaction { database in
                let currentUser = try request.auth.require(AffirmateUser.self)
                let chats = try await currentUser.$chats.query(on: database)
                    .with(\.$messages) {
                        $0.with(\.$sender) {
                            $0
                                .with(\.$user)
                                .with(\.$publicKey)
                        }
                        .with(\.$recipient) {
                            $0
                                .with(\.$user)
                                .with(\.$publicKey)
                        }
                    }
                    .with(\.$participants) {
                        $0
                            .with(\.$user)
                            .with(\.$publicKey)
                    }
                    .all()
                return try chats.compactMap { chat in
                    return Chat.GetResponse(
                        id: try chat.requireID(),
                        name: chat.name,
                        messages: try chat.messages.filter({ $0.recipient.user.id == currentUser.id }).map { message in
                            Message.GetResponse(
                                id: try message.requireID(),
                                text: Message.Sealed(
                                    ephemeralPublicKeyData: message.ephemeralPublicKeyData,
                                    ciphertext: message.ciphertext,
                                    signature: message.signature
                                ),
                                chat: Chat.MessageResponse(id: try chat.requireID()),
                                sender: Participant.GetResponse(
                                    id: try message.sender.requireID(),
                                    role: message.sender.role,
                                    user: AffirmateUser.ParticipantResponse(
                                        id: try message.sender.user.requireID(),
                                        username: message.sender.user.username
                                    ),
                                    chat: Chat.ParticipantResponse(id: try chat.requireID()),
                                    signingKey: message.sender.publicKey.signingKey,
                                    encryptionKey: message.sender.publicKey.encryptionKey
                                ),
                                recipient: Participant.GetResponse(
                                    id: try message.recipient.requireID(),
                                    role: message.recipient.role,
                                    user: AffirmateUser.ParticipantResponse(
                                        id: try message.recipient.user.requireID(),
                                        username: message.recipient.user.username
                                    ),
                                    chat: Chat.ParticipantResponse(id: try chat.requireID()),
                                    signingKey: message.recipient.publicKey.signingKey,
                                    encryptionKey: message.recipient.publicKey.encryptionKey
                                ),
                                created: message.created
                            )
                        },
                        participants: try chat.participants.map { participant in
                            Participant.GetResponse(
                                id: try participant.requireID(),
                                role: participant.role,
                                user: AffirmateUser.ParticipantResponse(
                                    id: try participant.user.requireID(),
                                    username: participant.user.username
                                ),
                                chat: Chat.ParticipantResponse(id: try chat.requireID()),
                                signingKey: participant.publicKey.signingKey,
                                encryptionKey: participant.publicKey.encryptionKey
                            )
                        },
                        salt: chat.salt
                    )
                }
            }
        }
        
        let specificChat = chats.grouped(":chatId")
        
        // MARK: - POST "/chat/:chatId/invite": Invite a new user to the chat.
        let invite = specificChat.grouped("invite")
        invite.post { request async throws -> HTTPStatus in
            try await request.db.transaction { database in
                let currentUser = try request.auth.require(AffirmateUser.self)
                let invitationCreate = try request.content.decode(ChatInvitation.Create.self)
                let (chatId, _) = try await getChat(request: request, database: database)
                let invitation = ChatInvitation(
                    role: invitationCreate.role,
                    user: invitationCreate.user,
                    invitedBy: try currentUser.requireID(),
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
                let confirmation = try request.content.decode(ChatInvitation.Join.self)
                let currentUser = try request.auth.require(AffirmateUser.self)
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
                    role: .admin,
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
                let declination = try request.content.decode(ChatInvitation.Decline.self)
                let currentUser = try request.auth.require(AffirmateUser.self)
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
    
    func getInvitation(chat: Chat, currentUser: AffirmateUser, database: Database) async throws -> ChatInvitation {
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
    
    func deleteInvitation(id: UUID, currentUser: AffirmateUser, chat: Chat, database: Database) async throws {
        try await currentUser.$chatInvitations.detach(chat, on: database)
        if let chatInvitation = try await ChatInvitation.find(id, on: database) {
            try await chatInvitation.delete(on: database)
        }
    }
}
