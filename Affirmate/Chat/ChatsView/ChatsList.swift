//
//  ChatsList.swift
//  Affirmate
//
//  Created by Bri on 10/7/22.
//

import SwiftUI

struct ChatsList: View {
    
    var chats: [Chat]
    
#if !os(watchOS)
    @Binding var selectedChat: Chat?
#endif
    
    @EnvironmentObject var chatsObserver: ChatsObserver
    @EnvironmentObject var authenticationObserver: AuthenticationObserver
    
    @SceneStorage("chat.isShowingNewChat") var isShowingNewChat = false
    
    var getChats: () async -> ()
    
    var body: some View {
#if !os(watchOS)
        List(selection: $selectedChat) {
            Chats(chats: chats)
        }
        .populateChatsList(getChats)
#else
        List {
            Chats(chats: chats)
        }
        .populateChatsList(getChats)
        .navigationDestination(for: Chat.self) { chat in
            if let chatId = chat.id, let chatObserver = chatsObserver.chatObservers[chatId] {
                ChatView(chatId: chatId)
                    .environmentObject(chatObserver)
            }
        }
#endif
    }
}

// TODO: Fix previews
//struct ChatsList_Previews: PreviewProvider {
//    static var previews: some View {
//#if !os(watchOS)
//        ChatsList(chats: [], selectedChat: .constant(UUID()), getChats: {})
//#else
//        ChatsList(chats: [], getChats: {})
//#endif
//    }
//}
