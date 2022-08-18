//
//  ChatObserver.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import Foundation
import SwiftUI

final class ChatObserver: ObservableObject {
    
    @Published var chat: Chat
    
    let actor = ChatsActor()
    
    init(chat: Chat) {
        self.chat = chat
    }
    
    func getChat(chatId: UUID) async throws {
        let chat = try await actor.get(chatId)
        await setData(from: chat)
    }
    
    func sendMessage(_ text: String) async throws {
        guard let chatId = chat.id else {
            throw ChatError.chatIdNotFound
        }
        try await actor.sendMessage(text, chatId: chatId)
    }
    
    @MainActor func setData(from chat: Chat) {
        withAnimation {
            self.chat = chat
        }
    }
}
