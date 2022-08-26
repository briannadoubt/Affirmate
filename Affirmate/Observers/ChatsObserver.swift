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
        let chats = try await actor.get()
        await updateChats(with: chats)
    }
    
    func newChat(_ createChat: Chat.Create) async throws {
        try await actor.create(createChat)
    }
}

private extension ChatsObserver {
    @MainActor func updateChats(with newChats: [Chat]) {
        withAnimation {
            self.chats = newChats
        }
    }
}
