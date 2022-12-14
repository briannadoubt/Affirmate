//
//  ChatInvitationsObserver.swift
//  Affirmate
//
//  Created by Bri on 10/12/22.
//

import AffirmateShared
import Foundation

class ChatInvitationObserver: ObservableObject {
    
    let actor = ChatActor()
    let crypto = AffirmateCrypto()
    
    func joinChat(_ chatId: UUID, confirmation: ChatInvitationJoin) async throws {
        try await actor.joinChat(chatId, confirmation: confirmation)
    }
    
    func declineInvitation(_ chatId: UUID, declination: ChatInvitationDecline) async throws {
        try await actor.declineInvitation(chatId, declination: declination)
    }
}
