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
                let newChat = Chat(id: chatCreate.id, name: chatCreate.name)
                try await newChat.save(on: database)
                let currentUser = try request.auth.require(AffirmateUser.self)
                let newPublicKey = try PublicKey(
                    data: chatCreate.publicKey,
                    user: currentUser.requireID(),
                    chat: newChat.requireID()
                )
                try await newChat.$publicKeys.create(newPublicKey, on: database)
                let newPreKeys = try chatCreate.preKeys.map { data in
                    try PreKey(
                        data: data,
                        user: currentUser.requireID(),
                        chat: newChat.requireID()
                    )
                }
                try await newChat.$preKeys.create(newPreKeys, on: database)
                for participantCreate in chatCreate.participants {
                    try await self.invite(participantCreate, from: currentUser.requireID(), to: newChat, on: database)
                }
                let currentParticipant = Participant(
                    role: .admin,
                    signedPreKey: chatCreate.signedPreKey,
                    user: try currentUser.requireID(),
                    chat: try newChat.requireID()
                )
                try await newChat.$participants.create(currentParticipant, on: database)
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
                            $0.with(\.$user)
                        }
                    }
                    .with(\.$participants) {
                        $0.with(\.$user)
                    }
                    .with(\.$preKeys) {
                        $0
                            .with(\.$invitation)
                            .with(\.$user)
                    }
                    .all()
                return try chats.map { chat in
                    guard let preKey = try chat.preKeys.first(
                        where: { preKey in
                            try preKey.invitation?.user.requireID() == currentUser.requireID() && preKey.chat.requireID() == chat.requireID()
                        }
                    ) else {
                        throw ChatError.preKeyNotFound
                    }
                    guard let invitation = preKey.invitation else {
                        throw ChatError.preKeyDoesNotHaveAssociatedInvitation
                    }
                    return Chat.GetResponse(
                        id: try chat.requireID(),
                        name: chat.name,
                        messages: try chat.messages.map { message in
                            Message.GetResponse(
                                id: try message.requireID(),
                                text: message.text,
                                chat: Chat.MessageResponse(id: try chat.requireID()),
                                sender: Participant.GetResponse(
                                    id: try message.sender.requireID(),
                                    role: message.sender.role,
                                    user: AffirmateUser.ParticipantReponse(
                                        id: try message.sender.user.requireID(),
                                        username: message.sender.user.username
                                    ),
                                    chat: Chat.ParticipantResponse(id: try chat.requireID()),
                                    signedPreKey: message.sender.signedPreKey
                                ),
                                created: message.created
                            )
                        },
                        participants: try chat.participants.map { participant in
                            Participant.GetResponse(
                                id: try participant.requireID(),
                                role: participant.role,
                                user: AffirmateUser.ParticipantReponse(
                                    id: try participant.user.requireID(),
                                    username: participant.user.username
                                ),
                                chat: Chat.ParticipantResponse(id: try chat.requireID()),
                                signedPreKey: participant.signedPreKey
                            )
                        },
                        preKey: PreKey.ChatGetResponse(
                            id: try preKey.requireID(),
                            data: preKey.data,
                            invitation: ChatInvitation.GetResponse(
                                id: try invitation.requireID(),
                                role: invitation.role,
                                userId: try invitation.user.requireID(),
                                invitedBy: try invitation.invitedBy.requireID(),
                                invitedByUsername: invitation.invitedBy.username,
                                chatId: try invitation.chat.requireID(),
                                chatParticipantUsernames: invitation.chat.participants.map {
                                    $0.user.username
                                },
                                invitedBySignedPreKey: invitation.invitedBySignedPreKey,
                                invitedByIdentity: invitation.invitedByIdentity
                            )
                        )
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
                let invitation = try request.content.decode(ChatInvitation.Create.self)
                let (chatId, chat) = try await getChat(request: request, database: database)
                guard let preKey = try await chat.$preKeys.query(on: database).first() else {
                    throw Abort(.notFound)
                }
                try await self.invite(
                    invitation.user,
                    role: invitation.role,
                    from: currentUser.requireID(),
                    preKey: preKey,
                    invitedBySignedPreKey: invitation.invitedBySignedPreKey,
                    invitedByIdentity: invitation.invitedByIdentity,
                    chat: chatId,
                    on: database
                )
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
                try await chat.$participants.create(
                    Participant(
                        role: invitation.role,
                        signedPreKey: confirmation.signedPreKey,
                        user: invitation.user.requireID(),
                        chat: chatId
                    ),
                    on: database
                )
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
    
    func invite(
        _ participantCreate: Participant.Create,
        from invitedBy: UUID,
        to chat: Chat,
        on database: Database
    ) async throws {
        guard let preKey = try await chat.$preKeys.query(on: database).first() else {
            throw Abort(.notFound)
        }
        try await invite(
            participantCreate.user,
            role: participantCreate.role,
            from: invitedBy,
            preKey: preKey,
            invitedBySignedPreKey: participantCreate.invitedBySignedPreKey,
            invitedByIdentity: participantCreate.invitedByIdentity,
            chat: chat.requireID(),
            on: database
        )
    }
    
    func invite(
        _ user: UUID,
        role: Participant.Role,
        from invitedBy: UUID,
        preKey: PreKey,
        invitedBySignedPreKey: Data,
        invitedByIdentity: Data,
        chat: UUID,
        on database: Database
    ) async throws {
        let chatInvitation = ChatInvitation(
            role: role,
            invitedBySignedPreKey: invitedBySignedPreKey,
            invitedByIdentity: invitedByIdentity,
            user: user,
            invitedBy: invitedBy,
            chat: chat
        )
        try await chatInvitation.save(on: database)
        preKey.$invitation.id = try chatInvitation.requireID()
        try await preKey.save(on: database)
    }
    
    func deleteInvitation(id: UUID, currentUser: AffirmateUser, chat: Chat, database: Database) async throws {
        try await currentUser.$chatInvitations.detach(chat, on: database)
        if let chatInvitation = try await ChatInvitation.find(id, on: database) {
            try await chatInvitation.$preKey.load(on: database)
            try await chatInvitation.preKey?.delete(on: database)
            try await chatInvitation.delete(on: database)
        }
    }
}
