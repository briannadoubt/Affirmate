//
//  ChatInvitationsObserver.swift
//  Affirmate
//
//  Created by Bri on 10/12/22.
//

import Foundation

class ChatInvitationObserver: ObservableObject {
    
    let actor = ChatActor()
    
    func joinChat(_ chatId: UUID, confirmation: ChatInvitation.Join) async throws {
        try await actor.joinChat(chatId, confirmation: confirmation)
    }
    
    func declineInvitation(_ chatId: UUID, declination: ChatInvitation.Decline) async throws {
        try await actor.declineInvitation(chatId, declination: declination)
    }
}
