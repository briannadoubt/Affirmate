//
//  ChatNavigationLink.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI
import SwiftKeychainWrapper

enum ChatError: LocalizedError {
    case failedToBuildURL
    case failedToRetrieveTokenFromKeychain
    case serverError(ServerError)
}

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
    
    @MainActor func setData(from chat: Chat) {
        self.chat = chat
    }
}

struct ChatNavigationLink: View {
    
    @StateObject var chatObserver: ChatObserver
    let chat: Chat
    
    @State var lastMessageText: String?
    
    init(chat: Chat) {
        self.chat = chat
        _chatObserver = StateObject(wrappedValue: ChatObserver(chat: chat))
    }
    
    var body: some View {
        NavigationLink {
//            ChatView(chat: chat)
//                .environmentObject(chatObserver)
        } label: {
            VStack {
                if let lastMessage = chatObserver.chat.messages?.last {
                    Text((lastMessage.sender.username ?? "") + ": ").bold()
                    Text(lastMessage.text)
                } else {
                    Text("No messages yet...")
                }
            }
        }
    }
}

//struct ChatNavigationLink_Previews: PreviewProvider {
//    static var previews: some View {
//        ChatNavigationLink()
//        )
//    }
//}
