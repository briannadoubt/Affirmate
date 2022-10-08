//
//  ChatsList.swift
//  Affirmate
//
//  Created by Bri on 10/7/22.
//

import SwiftUI

struct ChatsList: View {
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
            Chats()
        }
        .populateChatsList(getChats)
#else
        List {
            Chats()
        }
        .populateChatsList(getChats)
        .navigationDestination(for: Chat.self) { chat in
            ChatView()
                .environmentObject(ChatObserver(chat: chat))
        }
#endif
    }
}

struct ChatsList_Previews: PreviewProvider {
    static var previews: some View {
#if !os(watchOS)
        ChatsList(selectedChat: .constant(Chat(id: UUID())), getChats: {})
#else
        ChatsList(getChats: {})
#endif
    }
}
