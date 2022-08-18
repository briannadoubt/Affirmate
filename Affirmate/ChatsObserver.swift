//
//  ChatObserver.swift
//  Affirmate
//
//  Created by Bri on 8/7/22.
//

import Foundation
import SwiftUI

final class ChatsObserver: ObservableObject {
    
    @Published var chats: [Chat] = []
    let actor = ChatsActor()
    
    func getChats() async throws {
        await updateChats(with: try await actor.get())
    }
    
    func newChat(_ createChat: Chat.Create) async throws {
        try await actor.create(createChat)
    }
}

private extension ChatsObserver {
    
    @MainActor func updateChats(with newChats: [Chat]) {
//        guard let updatedChatResponses = chats.applying(chats.difference(from: newChats).inferringMoves()) else {
//            return
//        }
        withAnimation {
            self.chats = newChats
        }
    }
}
